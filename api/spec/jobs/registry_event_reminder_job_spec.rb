require 'rails_helper'

RSpec.describe RegistryEventReminderJob, type: :job do
  include ActiveJob::TestHelper

  let(:today) { Date.current }

  def registry(**attrs)
    create(:wish_list, :standalone, event_date: today + 10, **attrs)
  end

  def run
    perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) { described_class.perform_now }
    ActionMailer::Base.deliveries
  end

  before { ActionMailer::Base.deliveries.clear }

  it 'reminds the owner once when the event is inside the window' do
    list = registry
    expect(run.map(&:to)).to eq([ [ list.user.email ] ])
    expect(list.reload.event_reminded_at).to be_present

    ActionMailer::Base.deliveries.clear
    expect(run).to be_empty
  end

  it 'skips events that are far off, already past, or have no date' do
    create(:wish_list, :standalone, event_date: today + 60)
    create(:wish_list, :standalone, event_date: today - 1)
    create(:wish_list, :standalone, event_date: nil)
    expect(run).to be_empty
  end

  it 'respects the opt-out' do
    registry(remind_owner: false)
    expect(run).to be_empty
  end

  it 'asks the owner to finish an unshared registry and to send a shared one' do
    registry(visible: false)
    expect(run.last.body.encoded).to include('isn')
    expect(run.last.body.encoded).to include('Finish my registry')

    ActionMailer::Base.deliveries.clear
    registry(visible: true)
    expect(run.last.body.encoded).to include('Open my registry')
  end

  it 'rearms the reminder when the date changes' do
    list = registry
    run
    list.reload.update!(event_date: today + 12)
    expect(list.reload.event_reminded_at).to be_nil
  end

  it 'does not touch invitation-owned wish lists' do
    create(:wish_list, event_date: today + 3)
    expect(run).to be_empty
  end
end
