# frozen_string_literal: true

# RubyLLM Configuration for multiple AI providers
# Non-sensitive config is in config/ai_config.yml
# Sensitive data (API keys) comes from environment variables

require "yaml"
require "ruby_llm"

AI_CONFIG = YAML.load_file(Rails.root.join("config/ai_config.yml"), aliases: true).with_indifferent_access

RubyLLM.configure do |config|
  # Remote providers
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.vertexai_project_id = ENV["GOOGLE_CLOUD_PROJECT"] # Available in v1.7.0+
  config.vertexai_location = ENV["GOOGLE_CLOUD_LOCATION"]
  config.deepseek_api_key = ENV["DEEPSEEK_API_KEY"]
  config.mistral_api_key = ENV["MISTRAL_API_KEY"]
  config.perplexity_api_key = ENV["PERPLEXITY_API_KEY"]
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]

  # Local providers
  config.ollama_api_base = "http://localhost:11434/v1"
  config.gpustack_api_base = ENV["GPUSTACK_API_BASE"]
  config.gpustack_api_key = ENV["GPUSTACK_API_KEY"]

  # AWS Bedrock (uses standard AWS credential chain if not set)
  config.bedrock_api_key = ENV["AWS_ACCESS_KEY_ID"]
  config.bedrock_secret_key = ENV["AWS_SECRET_ACCESS_KEY"]
  config.bedrock_region = ENV["AWS_REGION"] # Required for Bedrock
  config.bedrock_session_token = ENV["AWS_SESSION_TOKEN"] # For temporary credentials

  # Common settings across all providers
  config.request_timeout = AI_CONFIG["default"]["request_timeout"]
  config.max_retries = AI_CONFIG["default"]["max_retries"]

  # Advanced retry behavior
  config.retry_interval = AI_CONFIG["default"]["retry_interval"] # Initial retry delay in seconds (default: 0.1)
  config.retry_backoff_factor = AI_CONFIG["default"]["retry_backoff_factor"] # Exponential backoff multiplier (default: 2)
  config.retry_interval_randomness = AI_CONFIG["default"]["retry_interval_randomness"]  # Jitter to prevent thundering herd (default: 0.5)
end
