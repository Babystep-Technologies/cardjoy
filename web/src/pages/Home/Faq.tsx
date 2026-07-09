import { useEffect, useMemo } from 'react';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';

const faqs = [
  {
    question: 'What is CardJoy?',
    answer:
      'CardJoy is a 100% free, open-source platform for creating digital group cards and event invitations. Collect heartfelt messages on a shareable group card, or design an animated invitation with built-in RSVP tracking. No paywalls, no hidden fees!',
  },
  {
    question: 'How much does it cost?',
    answer:
      'Everything is completely FREE! There are no credits to buy, no subscriptions, and no paywalls. Create as many cards as you want, whenever you want.',
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

export default function Faq() {
  // Generate FAQ structured data for AI discovery
  const faqSchema = useMemo(
    () => ({
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: faqs.map(faq => ({
        '@type': 'Question',
        name: faq.question,
        acceptedAnswer: {
          '@type': 'Answer',
          text: faq.answer,
        },
      })),
    }),
    []
  );

  // Inject FAQ schema into the page head for AI crawlers
  useEffect(() => {
    const script = document.createElement('script');
    script.type = 'application/ld+json';
    script.text = JSON.stringify(faqSchema);
    script.id = 'faq-schema';
    document.head.appendChild(script);

    return () => {
      const existingScript = document.getElementById('faq-schema');
      if (existingScript) {
        document.head.removeChild(existingScript);
      }
    };
  }, [faqSchema]);

  return (
    <section className="pt-16 pb-32 px-4 md:px-8 max-w-3xl mx-auto">
      <div className="text-center mb-10">
        <h1 className="text-3xl md:text-5xl font-black text-gray-900">
          Frequently Asked Questions
        </h1>
      </div>

      <Accordion type="multiple" className="w-full space-y-4">
        {faqs.map((faq, index) => (
          <AccordionItem
            key={index}
            value={`item-${index}`}
            className="border-2 border-gray-300 rounded-2xl bg-white shadow-md hover:shadow-lg transition-shadow"
          >
            <AccordionTrigger className="text-left text-gray-900 text-base md:text-lg font-bold px-6 py-4 hover:no-underline">
              {faq.question}
            </AccordionTrigger>
            <AccordionContent className="px-6 pb-6 text-sm md:text-base text-gray-700 leading-relaxed">
              {faq.answer}
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
}
