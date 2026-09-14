// Shared with the support widget's self-serve panel — one FAQ list backing both the marketing
// page and the global support surface.
export interface Faq {
  question: string;
  answer: string;
}

export const faqs: Faq[] = [
  {
    question: 'What is CardJoy?',
    answer:
      'CardJoy is an open-source platform for creating digital group cards and event invitations. Collect heartfelt messages on a shareable group card, or design an animated invitation with built-in RSVP tracking. No subscriptions, no hidden fees!',
  },
  {
    question: 'How much does it cost?',
    answer:
      'You start with 5 free credits when you sign up, and creating a card or invitation costs 1 credit. When you run out, you can buy more credits — no subscriptions, no lock-in.',
  },
  {
    question: 'How do I create a group card?',
    answer:
      "Click 'Create for Your Moment', pick a design, and customize it. Share the link with friends and family so everyone can add their messages. When ready, send it to the recipient!",
  },
  {
    question: 'How fast will they get my card?',
    answer:
      "Instantly! Share the link via text, email, or social media and they'll receive it immediately.",
  },
  {
    question: 'Can I use a QR code for my event?',
    answer:
      'Yes! Group cards come with a QR code you can print and display at your event for easy scanning.',
  },
  {
    question: 'Can I make edits after sending?',
    answer: 'Yes! You can update your card details anytime.',
  },
  {
    question: 'Is CardJoy really open source?',
    answer:
      'Yes! CardJoy is fully open source. You can inspect the code, self-host it on your own infrastructure, or contribute on GitHub at https://github.com/Babystep-Technologies/cardjoy. No lock-in and no hidden data practices.',
  },
  {
    question: 'Is my data safe and secure?',
    answer:
      'Absolutely. We use industry-standard encryption, follow best practices for cloud security, and comply with regulations like GDPR. Your data is yours—we never share it without your permission.',
  },
  {
    question: 'How do I get support if I need help?',
    answer:
      "We offer email support and aim to respond within 24 hours on weekdays. Replies over the weekend may take a bit longer, but we'll get back to you as soon as we can.",
  },
];
