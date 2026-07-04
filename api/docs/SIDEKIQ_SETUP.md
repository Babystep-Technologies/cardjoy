# Sidekiq Background Jobs Setup

This document explains the asynchronous job processing setup using Sidekiq for the Cardjoy API.

## Overview

We use Sidekiq for background job processing to handle tasks that don't need to complete within a web request, such as sending notification emails to RSVP guests when an invitation is updated.

## Components

### 1. Sidekiq Configuration
- **File**: `config/initializers/sidekiq.rb`
- **Purpose**: Configures Sidekiq client and server to connect to Redis
- **Environment Variable**: `REDIS_URL` (defaults to `redis://localhost:6379/0`)

### 2. Queue Configuration
- **File**: `config/sidekiq.yml`
- **Queues**:
  - `default` - General background jobs
  - `mailers` - Email-related jobs
- **Concurrency**: Varies by environment (dev: 2, staging: 5, production: 10)

### 3. Background Jobs

#### NotifyRsvpsOfUpdateJob
- **File**: `app/jobs/notify_rsvps_of_update_job.rb`
- **Purpose**: Sends update notifications to all RSVPs with "going" or "maybe" status when an invitation is updated
- **Queue**: `default`
- **Usage**: Automatically enqueued by `UpdateInvitation` mutation

## Development Setup

### Starting Redis

Redis must be running for Sidekiq to work. In development, Redis runs in Docker:

```bash
docker compose up -d
```

### Starting Sidekiq Worker

To process background jobs in development, run Sidekiq in a separate terminal:

```bash
docker compose exec api bundle exec sidekiq
```

### Testing Background Jobs

Tests use the `:test` queue adapter which processes jobs inline:

```bash
docker compose exec api bundle exec rspec spec/jobs/
```

## Production Deployment

### Kubernetes Setup

The application now includes three main deployments:

1. **API Server** (`templates/deployment.yaml`)
   - Runs the Rails web server
   - Enqueues background jobs to Redis
   - Environment variable: `REDIS_URL` points to Redis service

2. **Sidekiq Workers** (`templates/sidekiq-deployment.yaml`)
   - Processes background jobs from Redis
   - Scales independently from web servers
   - Environment variable: `REDIS_URL` points to Redis service
   - Replica count controlled by `sidekiq.replicaCount` in values.yaml

3. **Redis** (`templates/redis-deployment.yaml` & `templates/redis-service.yaml`)
   - Acts as the job queue/message broker
   - Deployed as a single pod with ClusterIP service
   - Accessible at: `cardjoy-redis-{env}:6379`

### Environment Variables

Set these environment variables in your production environment:

```bash
REDIS_URL=redis://cardjoy-redis-production:6379/0
```

### Scaling Sidekiq Workers

Adjust the number of Sidekiq workers in `values.yaml`:

```yaml
sidekiq:
  replicaCount: 3  # Increase for more throughput
```

Or for specific environments:

```yaml
# values/production.yaml
sidekiq:
  replicaCount: 5
```

### Monitoring

To monitor Sidekiq jobs:

```bash
# View Sidekiq logs
kubectl logs -f deployment/cardjoy-sidekiq-production -n cardjoy

# Check pod status
kubectl get pods -n cardjoy | grep sidekiq
```

## Usage

### Enqueueing Jobs

Jobs are automatically enqueued when an invitation is updated:

```ruby
# In mutations/update_invitation.rb
NotifyRsvpsOfUpdateJob.perform_later(invitation.id)
```

### Manual Job Execution (for testing)

```ruby
# Enqueue a job
NotifyRsvpsOfUpdateJob.perform_later(invitation_id)

# Execute immediately (not recommended in production)
NotifyRsvpsOfUpdateJob.perform_now(invitation_id)
```

## Troubleshooting

### Connection Refused Errors

If you see Redis connection errors:

1. Ensure Redis is running:
   ```bash
   docker compose ps redis
   ```

2. Check Redis connectivity:
   ```bash
   docker compose exec api redis-cli -h localhost ping
   ```

3. Verify REDIS_URL environment variable:
   ```bash
   docker compose exec api env | grep REDIS_URL
   ```

### Jobs Not Processing

1. Check Sidekiq is running:
   ```bash
   docker compose exec api ps aux | grep sidekiq
   ```

2. Start Sidekiq manually:
   ```bash
   docker compose exec api bundle exec sidekiq
   ```

3. Check for errors in Sidekiq logs

### In Production

If jobs aren't processing in production:

1. Check Sidekiq pod status:
   ```bash
   kubectl get pods -n cardjoy | grep sidekiq
   ```

2. View Sidekiq logs:
   ```bash
   kubectl logs deployment/cardjoy-sidekiq-production -n cardjoy
   ```

3. Verify Redis is accessible:
   ```bash
   kubectl exec -it deployment/cardjoy-sidekiq-production -n cardjoy -- redis-cli -h cardjoy-redis-production ping
   ```

## Performance Considerations

- **Concurrency**: Adjust `concurrency` in `config/sidekiq.yml` based on your workload
- **Replica Count**: Scale Sidekiq workers horizontally by increasing `sidekiq.replicaCount`
- **Redis Memory**: Monitor Redis memory usage and adjust resources as needed
- **Job Retries**: Sidekiq automatically retries failed jobs (default: 25 attempts with exponential backoff)

## Migration from Synchronous Processing

The previous implementation processed RSVP notifications synchronously within the web request. This has been moved to a background job to improve:

- **Response Time**: Web requests return faster
- **Scalability**: Background job processing can scale independently
- **Reliability**: Failed notifications are automatically retried
- **User Experience**: API endpoints don't timeout for invitations with many RSVPs
