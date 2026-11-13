/**
 * A printable QR code for the registry's guest link (#247), for showers and parties where people
 * can't tap a link. The SVG is drawn by the API (owner-only); here it's shown as an image and
 * offered as a download.
 */
import React from 'react';
import { gql, useQuery } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

const GET_REGISTRY_QR = gql`
  query GetRegistryQr($externalId: String!) {
    registry(externalId: $externalId) {
      externalId
      qrSvg
    }
  }
`;

export const ShareQrCode: React.FC<{ externalId: string }> = ({ externalId }) => {
  const { data } = useQuery(GET_REGISTRY_QR, { variables: { externalId } });
  const svg: string | null | undefined = data?.registry?.qrSvg;
  if (!svg) return null;

  const src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;

  return (
    <Card className="mt-6">
      <CardHeader>
        <CardTitle>Share with a QR code</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col items-center gap-3 sm:flex-row sm:items-start">
        <img src={src} alt="QR code for your registry" className="h-40 w-40 rounded border p-2" />
        <div className="space-y-3 text-sm text-gray-600">
          <p>Print it on an invitation or show it at the party. It opens your registry.</p>
          <Button variant="outline" size="sm" asChild>
            <a href={src} download={`registry-${externalId}-qr.svg`}>
              Download
            </a>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};
