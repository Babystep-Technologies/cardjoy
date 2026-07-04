import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';

export default function TermsOfService() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle className="text-3xl font-bold">Terms of Service</CardTitle>
          <p className="text-sm text-muted-foreground">Effective Date: May 22, 2025</p>
        </CardHeader>
        <CardContent>
          <ScrollArea className="h-[70vh] pr-4">
            <div className="space-y-6 text-base leading-relaxed">
              <p>
                Welcome to CardJoy! By using our service, you agree to the following Terms of
                Service (“Terms”). Please read them carefully.
              </p>

              <h2 className="text-xl font-semibold">1. Overview</h2>
              <p>
                CardJoy provides an online platform that allows users to create and share digital
                greeting cards. These Terms govern your use of the CardJoy website, app, and related
                services.
              </p>

              <h2 className="text-xl font-semibold">2. Eligibility</h2>
              <p>
                You must be at least 13 years old to use CardJoy. If you are under 18, you must have
                permission from a parent or guardian.
              </p>

              <h2 className="text-xl font-semibold">3. User Accounts</h2>
              <p>
                Registered users are responsible for maintaining the confidentiality of their login
                credentials. You are responsible for all activity that occurs under your account.
              </p>
              <p>
                We may suspend or terminate your account if we detect suspicious, abusive, or
                harmful behavior.
              </p>

              <h2 className="text-xl font-semibold">4. Content Ownership</h2>
              <p>
                You retain ownership of the content you submit to CardJoy (e.g., messages, images).
                By uploading content, you grant us a limited, non-exclusive license to display,
                store, and share it as part of the CardJoy experience.
              </p>

              <h2 className="text-xl font-semibold">5. Prohibited Uses</h2>
              <p>You agree not to use CardJoy to:</p>
              <ul className="list-disc list-inside ml-4">
                <li>Violate any laws</li>
                <li>Post harmful, abusive, or explicit content</li>
                <li>Harass, impersonate, or harm others</li>
                <li>Upload viruses or attempt to disrupt the platform</li>
              </ul>

              <h2 className="text-xl font-semibold">6. Data and Privacy</h2>
              <p>
                We respect your privacy. Please refer to our{' '}
                <a href="/privacy" className="underline text-primary">
                  Privacy Policy
                </a>{' '}
                for how we handle your data. We do not sell or share your data with third parties
                for advertising.
              </p>

              <h2 className="text-xl font-semibold">7. Availability</h2>
              <p>
                We strive for uptime and availability, but we do not guarantee uninterrupted
                service. We may change or discontinue features without prior notice.
              </p>

              <h2 className="text-xl font-semibold">8. Limitation of Liability</h2>
              <p>
                To the maximum extent permitted by law, CardJoy shall not be liable for indirect,
                incidental, or consequential damages arising from your use of the service.
              </p>

              <h2 className="text-xl font-semibold">9. Changes to These Terms</h2>
              <p>
                We may update these Terms from time to time. Continued use of CardJoy after changes
                means you accept the revised Terms.
              </p>

              <h2 className="text-xl font-semibold">10. Contact</h2>
              <p>If you have any questions or concerns about these Terms, please reach out to:</p>
              <p>
                <strong>CardJoy Team</strong>
                <br />
                Email:{' '}
                <a className="underline" href="mailto:team.cardjoy@gmail.com">
                  team.cardjoy@gmail.com
                </a>
              </p>
            </div>
          </ScrollArea>
        </CardContent>
      </Card>
    </div>
  );
}
