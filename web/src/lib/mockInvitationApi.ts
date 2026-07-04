import { InvitationType, RSVPResponseType } from '@/types/app';

// Mock data storage (in a real app, this would be replaced with actual API calls)
const mockInvitations: InvitationType[] = [
  {
    id: 'inv-1',
    title: 'Summer Pool Party',
    description: 'Join us for a splashing good time! Bring your swimsuit and sunscreen.',
    location: '123 Beach Lane, Chicago, IL',
    eventDate: '2025-07-15',
    eventTime: '14:00',
    coverImageUrl: '/vanessa-collection/birthday.jpeg',
    specialInstructions: {
      allowPlusOne: true,
      attire: 'Swimwear & Beach Casual',
      customInstructions: 'Pool will be heated! Feel free to bring floaties.',
    },
    rsvpDeadline: '2025-07-10',
    createdBy: 'user-1',
    createdAt: new Date().toISOString(),
  },
];

const mockRSVPs: RSVPResponseType[] = [];

export const mockInvitationApi = {
  // Get all invitations
  getAllInvitations: async (): Promise<InvitationType[]> => {
    return new Promise(resolve => {
      setTimeout(() => resolve([...mockInvitations]), 300);
    });
  },

  // Get single invitation
  getInvitation: async (id: string): Promise<InvitationType | null> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const invitation = mockInvitations.find(inv => inv.id === id);
        resolve(invitation || null);
      }, 300);
    });
  },

  // Create invitation
  createInvitation: async (
    invitation: Omit<InvitationType, 'id' | 'createdAt'>
  ): Promise<InvitationType> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const newInvitation: InvitationType = {
          ...invitation,
          id: `inv-${Date.now()}`,
          createdAt: new Date().toISOString(),
        };
        mockInvitations.push(newInvitation);
        resolve(newInvitation);
      }, 500);
    });
  },

  // Update invitation
  updateInvitation: async (
    id: string,
    updates: Partial<InvitationType>
  ): Promise<InvitationType | null> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const index = mockInvitations.findIndex(inv => inv.id === id);
        if (index === -1) {
          resolve(null);
          return;
        }
        mockInvitations[index] = { ...mockInvitations[index], ...updates };
        resolve(mockInvitations[index]);
      }, 500);
    });
  },

  // Delete invitation
  deleteInvitation: async (id: string): Promise<boolean> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const index = mockInvitations.findIndex(inv => inv.id === id);
        if (index === -1) {
          resolve(false);
          return;
        }
        mockInvitations.splice(index, 1);
        resolve(true);
      }, 300);
    });
  },

  // RSVP methods
  getRSVPs: async (invitationId: string): Promise<RSVPResponseType[]> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const rsvps = mockRSVPs.filter(rsvp => rsvp.invitationId === invitationId);
        resolve(rsvps);
      }, 300);
    });
  },

  createRSVP: async (
    rsvp: Omit<RSVPResponseType, 'id' | 'createdAt'>
  ): Promise<RSVPResponseType> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const newRSVP: RSVPResponseType = {
          ...rsvp,
          id: `rsvp-${Date.now()}`,
          createdAt: new Date().toISOString(),
        };
        mockRSVPs.push(newRSVP);
        resolve(newRSVP);
      }, 500);
    });
  },

  updateRSVP: async (
    id: string,
    updates: Partial<RSVPResponseType>
  ): Promise<RSVPResponseType | null> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const index = mockRSVPs.findIndex(rsvp => rsvp.id === id);
        if (index === -1) {
          resolve(null);
          return;
        }
        mockRSVPs[index] = { ...mockRSVPs[index], ...updates };
        resolve(mockRSVPs[index]);
      }, 500);
    });
  },

  // Get RSVP counts
  getRSVPCounts: async (
    invitationId: string
  ): Promise<{ going: number; maybe: number; notGoing: number; total: number }> => {
    return new Promise(resolve => {
      setTimeout(() => {
        const rsvps = mockRSVPs.filter(rsvp => rsvp.invitationId === invitationId);
        const counts = {
          going: rsvps.filter(r => r.status === 'going').length,
          maybe: rsvps.filter(r => r.status === 'maybe').length,
          notGoing: rsvps.filter(r => r.status === 'not-going').length,
          total: rsvps.length,
        };
        resolve(counts);
      }, 300);
    });
  },
};
