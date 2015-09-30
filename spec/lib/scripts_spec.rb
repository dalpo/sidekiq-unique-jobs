require 'spec_helper'
RSpec.describe SidekiqUniqueJobs::Scripts do
  include ActiveSupport::Testing::TimeHelpers
  MD5_DIGEST  ||= 'unique'.freeze
  UNIQUE_KEY  ||= 'uniquejobs:unique'.freeze
  JID         ||= 'fuckit'.freeze
  ANOTHER_JID ||= 'anotherjid'.freeze

  context 'class methods' do
    subject { SidekiqUniqueJobs::Scripts }

    it { is_expected.to respond_to(:call).with(3).arguments }
    it { is_expected.to respond_to(:logger) }
    it { is_expected.to respond_to(:script_shas) }
    it { is_expected.to respond_to(:connection).with(1).arguments }
    it { is_expected.to respond_to(:script_source).with(1).arguments }
    it { is_expected.to respond_to(:script_path).with(1).arguments }

    describe '.script_shas' do
      its(:script_shas) { is_expected.to be_a(Hash) }
    end

    describe '.logger' do
      its(:logger) { is_expected.to eq(Sidekiq.logger) }
    end

    def lock_for(seconds = 1, jid = JID, key = UNIQUE_KEY)
      subject.call(:aquire_lock, nil, {
        keys: [key], argv: [jid, seconds]
      })
    end

    def unlock(key = UNIQUE_KEY, jid = JID)
      subject.call(:release_lock, nil, keys: [key], argv: [jid])
    end

    describe '.aquire_lock' do
      context 'when job is unique' do
        specify { expect(lock_for).to eq(1) }
        specify do
          expect(lock_for(0.5.seconds)).to eq(1)
          expect(Redis)
            .to have_key(UNIQUE_KEY)
            .for_seconds(1)
            .with_value('fuckit')
          sleep 0.5
          expect(lock_for).to eq(1)
        end

        context 'when job is locked' do
          before  { expect(lock_for).to eq(1) }
          specify { expect(lock_for).to eq(0) }
        end
      end
    end

    describe '.release_lock' do
      context 'when job is locked by another jid' do
        before  { expect(lock_for(10.seconds, 'anotherjid')).to eq(1) }
        specify { expect(unlock).to eq(0) }
        after { unlock(UNIQUE_KEY, ANOTHER_JID) }
      end

      context 'when job is not locked at all' do
        specify { expect(unlock).to eq(-1) }
      end

      context 'when job is locked by the same jid' do
        specify do
          expect(lock_for(10.seconds)).to eq(1)
          expect(unlock).to eq(1)
        end
      end
    end
  end
end
