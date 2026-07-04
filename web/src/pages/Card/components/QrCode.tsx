import { useEffect, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

const GET_CARD_QR_CODE = gql`
  query Card($cardId: ID!) {
    card(cardId: $cardId) {
      qrCodeUrl
    }
  }
`;

const GENERATE_QR_CODE = gql`
  mutation GenerateQrCode($input: GenerateQrCodeInput!) {
    generateQrCode(input: $input) {
      success
      errors
      qrCodeUrl
    }
  }
`;

export default function CardQrCode({
  cardExternalId,
  open,
  onClose,
}: {
  cardExternalId: string;
  open: boolean;
  onClose: () => void;
}) {
  const [qrCodeUrl, setQrCodeUrl] = useState<string | null>(null);
  const { data } = useQuery(GET_CARD_QR_CODE, {
    variables: { cardId: cardExternalId },
    skip: !open,
    fetchPolicy: 'network-only',
  });

  const [generateQrCode] = useMutation(GENERATE_QR_CODE);

  useEffect(() => {
    if (data?.card) {
      console.log('Card data:', data.card);
      if (data.card.qrCodeUrl) {
        setQrCodeUrl(data.card.qrCodeUrl);
      } else {
        generateQrCode({
          variables: { input: { cardExternalId } },
        }).then(({ data }) => {
          if (data?.generateQrCode?.success) {
            setQrCodeUrl(data.generateQrCode.qrCodeUrl);
          }
        });
      }
    }
  }, [data, generateQrCode, cardExternalId]);

  // opens a new tab with the QR code URL and also downloads the QR code image
  const download = async () => {
    if (!qrCodeUrl) return;

    window.open(qrCodeUrl, '_blank');
    try {
      const response = await fetch(qrCodeUrl);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);

      const a = document.createElement('a');
      a.href = url;
      a.download = `card-${cardExternalId}-qr-code.png`; // Force download with name
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Download failed:', err);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="text-center p-6 bg-white rounded-xl shadow-xl max-w-md w-full">
        <DialogHeader>
          <DialogTitle className="text-xl text-black font-bold">Card QR Code</DialogTitle>
        </DialogHeader>
        {qrCodeUrl ? (
          <>
            <img src={qrCodeUrl} alt="QR Code" className="mx-auto w-64 h-64" />
            <Button className="mt-4 bg-black text-white" onClick={download}>
              Download QR Code
            </Button>
          </>
        ) : (
          <p className="text-gray-600">Generating QR code...</p>
        )}
      </DialogContent>
    </Dialog>
  );
}
