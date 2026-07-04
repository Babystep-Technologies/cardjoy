import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';

export default function PrivacyPolicy() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle className="text-3xl font-bold">Privacy Policy</CardTitle>
          <p className="text-sm text-muted-foreground">Effective Date: May 22, 2025</p>
        </CardHeader>
        <CardContent>
          <ScrollArea className="h-[70vh] pr-4">
            <div className="space-y-6 text-base leading-relaxed">
              <p>
                CardJoy (“we”, “us”, or “our”) provides a platform for users to create, personalize,
                and share digital greeting cards with others.
              </p>

              <h2 className="text-xl font-semibold">1. Information We Collect</h2>
              <p>We collect information you provide when you use CardJoy, including:</p>
              <ul className="list-disc list-inside ml-4">
                <li>Name, email address, and optional profile image (for registered users)</li>
                <li>Guest name (for non-logged-in contributors)</li>
                <li>Messages, images, and other content you submit to greeting cards</li>
              </ul>

              <h2 className="text-xl font-semibold">2. How We Use Your Information</h2>
              <p>We use your information to:</p>
              <ul className="list-disc list-inside ml-4">
                <li>Create and manage your greeting cards</li>
                <li>Facilitate message submissions and collaboration</li>
                <li>Improve our platform and user experience</li>
                <li>Send email notifications (e.g. invitations, reminders, password resets)</li>
              </ul>

              <h2 className="text-xl font-semibold">3. Sharing and Disclosure</h2>
              <p>
                We do <strong>not</strong> sell, rent, or share your personal data with third
                parties for advertising or marketing.
              </p>
              <p>We may share data only in these cases:</p>
              <ul className="list-disc list-inside ml-4">
                <li>To comply with legal obligations</li>
                <li>To prevent fraud or abuse</li>
                <li>To support core infrastructure partners under strict confidentiality</li>
              </ul>

              <h2 className="text-xl font-semibold">4. Data Retention</h2>
              <p>
                We retain your card data and messages as long as your account or card remains
                active. You may request deletion at any time.
              </p>

              <h2 className="text-xl font-semibold">5. Your Choices</h2>
              <p>You may:</p>
              <ul className="list-disc list-inside ml-4">
                <li>Access, edit, or delete your profile</li>
                <li>Delete cards and their content</li>
                <li>
                  Contact us at{' '}
                  <a className="underline" href="mailto:team.cardjoy@gmail.com">
                    team.cardjoy@gmail.com
                  </a>{' '}
                  for data inquiries
                </li>
              </ul>

              <h2 className="text-xl font-semibold">6. Security</h2>
              <p>
                We use encryption, access controls, and monitoring to protect your data. However, no
                system is 100% secure.
              </p>

              <h2 className="text-xl font-semibold">7. Children's Privacy</h2>
              <p>CardJoy is not intended for use by children under 13 without parental consent.</p>

              <h2 className="text-xl font-semibold">8. Updates</h2>
              <p>
                We may update this policy from time to time. We will notify you of material changes.
              </p>

              <h2 className="text-xl font-semibold">9. Contact</h2>
              <p>If you have any questions or concerns, please contact us at:</p>
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
