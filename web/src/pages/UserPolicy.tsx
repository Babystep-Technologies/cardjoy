import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';

export default function UserPolicy() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle className="text-3xl font-bold">User Policy</CardTitle>
          <p className="text-sm text-muted-foreground">Effective Date: May 22, 2025</p>
        </CardHeader>
        <CardContent>
          <ScrollArea className="h-[70vh] pr-4">
            <div className="space-y-6 text-base leading-relaxed">
              <p>
                This User Policy outlines the acceptable use and behavior expectations for anyone
                using the CardJoy platform (“we”, “us”, or “our”). By using CardJoy, you agree to
                follow these guidelines.
              </p>

              <h2 className="text-xl font-semibold">1. Be Respectful</h2>
              <p>
                CardJoy is a platform for celebration and connection. Users must respect others when
                submitting messages, images, or other content. Harassment, hate speech,
                discrimination, or personal attacks are strictly prohibited.
              </p>

              <h2 className="text-xl font-semibold">2. Prohibited Content</h2>
              <p>You may not upload, share, or distribute content that:</p>
              <ul className="list-disc list-inside ml-4">
                <li>Contains hate speech, threats, or violence</li>
                <li>Is sexually explicit or pornographic</li>
                <li>Promotes illegal activity</li>
                <li>Includes copyrighted material without permission</li>
                <li>Contains malware, spam, or deceptive links</li>
              </ul>
              <p>We reserve the right to remove any content that violates this policy.</p>

              <h2 className="text-xl font-semibold">3. Account Responsibility</h2>
              <p>
                You are responsible for any activity conducted under your account. Do not share your
                login credentials. If you suspect unauthorized access, notify us immediately at{' '}
                <a href="mailto:team.cardjoy@gmail.com" className="underline">
                  team.cardjoy@gmail.com
                </a>
                .
              </p>

              <h2 className="text-xl font-semibold">4. Guest Contributions</h2>
              <p>
                Guests may contribute messages without creating an account. However, guest
                submissions must follow the same respectful and content standards.
              </p>

              <h2 className="text-xl font-semibold">5. Reporting Violations</h2>
              <p>
                If you see content or behavior that violates this User Policy, please report it to
                us at{' '}
                <a href="mailto:team.cardjoy@gmail.com" className="underline">
                  team.cardjoy@gmail.com
                </a>
                . We review all reports and may remove content or suspend accounts as necessary.
              </p>

              <h2 className="text-xl font-semibold">6. Enforcement</h2>
              <p>We reserve the right to:</p>
              <ul className="list-disc list-inside ml-4">
                <li>Remove content that violates this policy</li>
                <li>Suspend or terminate accounts with repeated or severe violations</li>
                <li>Limit access to features in response to abuse</li>
              </ul>

              <h2 className="text-xl font-semibold">7. Changes to this Policy</h2>
              <p>
                We may update this policy as needed. Continued use of CardJoy after changes means
                you agree to the updated terms.
              </p>

              <h2 className="text-xl font-semibold">8. Contact</h2>
              <p>If you have questions about this policy, please contact us:</p>
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
