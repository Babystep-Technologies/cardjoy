require "rails_helper"

RSpec.describe InboundEmailReplyExtractor do
  describe ".call" do
    it "returns the whole body when there is nothing quoted" do
      expect(described_class.call("Thanks, that worked!")).to eq("Thanks, that worked!")
    end

    it "returns an empty string for blank input" do
      expect(described_class.call(nil)).to eq("")
      expect(described_class.call("")).to eq("")
    end

    it "drops everything from a Gmail-style quote header down" do
      body = <<~BODY
        Still broken on my end.

        On Fri, Sep 12, 2026 at 1:00 PM Support <support@cardjoy.app> wrote:
        > Have you tried turning it off and on again?
      BODY

      expect(described_class.call(body)).to eq("Still broken on my end.")
    end

    it "drops everything from an Outlook original-message separator down" do
      body = <<~BODY
        Sounds good, thanks!

        -----Original Message-----
        From: Support <support@cardjoy.app>
        Sent: Friday
        Subject: Re: ticket
      BODY

      expect(described_class.call(body)).to eq("Sounds good, thanks!")
    end

    it "drops a signature and anything after it" do
      body = <<~BODY
        See you then.

        --
        Dana Host
        Sent from my iPhone
      BODY

      expect(described_class.call(body)).to eq("See you then.")
    end

    it "drops bare quoted lines even with no quote header" do
      body = <<~BODY
        Got it, will do.

        > original question here
        > second line of the quote
      BODY

      expect(described_class.call(body)).to eq("Got it, will do.")
    end
  end
end
