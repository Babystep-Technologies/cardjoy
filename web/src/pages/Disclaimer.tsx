import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';

export default function Disclaimer() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <Card>
        <CardHeader>
          <CardTitle className="text-3xl font-bold">Disclaimer</CardTitle>
          <p className="text-sm text-muted-foreground">Effective Date: May 22, 2025</p>
        </CardHeader>
        <CardContent>
          <ScrollArea className="h-[70vh] pr-4">
            <div className="space-y-6 text-base leading-relaxed">
              <p>
                The information provided by CardJoy (“we”, “us”, or “our”) on our website and
                platform is for general informational purposes only. All information is provided in
                good faith, but we make no representation or warranty regarding the accuracy,
                adequacy, validity, reliability, or completeness of any information.
              </p>

              <h2 className="text-xl font-semibold">1. No Professional Advice</h2>
              <p>
                CardJoy is a platform for creating and sharing greeting cards. We do not provide
                legal, medical, psychological, financial, or any other form of professional advice.
              </p>
              <p>
                Any content submitted or viewed through CardJoy should not be interpreted as
                professional advice. For such matters, consult a qualified professional.
              </p>

              <h2 className="text-xl font-semibold">2. User-Generated Content</h2>
              <p>
                CardJoy allows users and guests to submit messages, images, and other content. We do
                not actively moderate every submission and cannot guarantee the appropriateness,
                truthfulness, or legality of user-generated content.
              </p>
              <p>
                We disclaim all liability for any loss or damage caused by reliance on
                user-submitted content.
              </p>

              <h2 className="text-xl font-semibold">3. External Links</h2>
              <p>
                Our platform may contain links to third-party websites or services. These links are
                provided for convenience only. We do not endorse or assume responsibility for any
                third-party content.
              </p>

              <h2 className="text-xl font-semibold">4. Use at Your Own Risk</h2>
              <p>
                Your use of CardJoy is at your sole risk. The platform is provided “as is” and “as
                available” without any warranties.
              </p>

              <h2 className="text-xl font-semibold">5. Limitation of Liability</h2>
              <p>
                To the maximum extent permitted by law, we disclaim any liability for damages,
                including direct, indirect, incidental, or consequential damages arising from your
                use of or inability to use the service.
              </p>

              <h2 className="text-xl font-semibold">6. Contact</h2>
              <p>If you have any questions about this disclaimer, please contact us at:</p>
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
