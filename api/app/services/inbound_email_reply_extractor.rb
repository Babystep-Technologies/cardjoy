# typed: true
# frozen_string_literal: true

# Strips quoted history and signatures from an inbound email's plain-text body
# (#174) so a mailed-in reply reads as just the reply once it lands in a
# SupportTicket thread.
#
# Deliberately line-based rather than a parser: mail clients don't agree on a
# machine-readable "here's where the old message starts" marker, only on a
# handful of textual conventions that every mainstream client still produces.
# The first line matching any of these is treated as the end of the reply —
# everything from there on, including the line itself, is dropped.
module InboundEmailReplyExtractor
  extend T::Sig

  # Gmail, Apple Mail, and Outlook Web all precede the quoted block with this,
  # alone on its own line.
  QUOTE_HEADER = /\AOn .{0,200}wrote:\s*\z/i

  # Classic Outlook desktop reply/forward separator.
  ORIGINAL_MESSAGE = /\A-{2,}\s*Original Message\s*-{2,}\z/i

  # RFC 3676's signature delimiter — "-- ", though plenty of clients drop the
  # trailing space.
  SIGNATURE = /\A--\s?\z/

  # Line-prefix quoting (">", ">>", ...), the fallback for clients that quote
  # without any header line at all.
  QUOTED_LINE = /\A\s*>/

  sig { params(text: T.nilable(String)).returns(String) }
  def self.call(text)
    return "" if text.blank?

    kept = text.gsub("\r\n", "\n").split("\n").take_while do |line|
      !(line.match?(QUOTE_HEADER) || line.match?(ORIGINAL_MESSAGE) ||
        line.match?(SIGNATURE) || line.match?(QUOTED_LINE))
    end

    kept.join("\n").strip
  end
end
