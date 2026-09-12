import { gql } from '@apollo/client';

export const SUPPORT_TICKET_SUMMARY_FIELDS = gql`
  fragment SupportTicketSummaryFields on SupportTicket {
    id
    externalId
    subject
    category
    status
    lastCustomerReplyAt
    lastAdminReplyAt
    createdAt
  }
`;

export const SUPPORT_TICKET_MESSAGE_FIELDS = gql`
  fragment SupportTicketMessageFields on SupportTicketMessage {
    id
    authorKind
    authorName
    body
    createdAt
  }
`;

export const MY_SUPPORT_TICKETS = gql`
  query MySupportTickets {
    mySupportTickets {
      supportTickets {
        ...SupportTicketSummaryFields
      }
    }
  }
  ${SUPPORT_TICKET_SUMMARY_FIELDS}
`;

export const SUPPORT_TICKET = gql`
  query SupportTicket($externalId: String!) {
    supportTicket(externalId: $externalId) {
      ...SupportTicketSummaryFields
      messages {
        ...SupportTicketMessageFields
      }
    }
  }
  ${SUPPORT_TICKET_SUMMARY_FIELDS}
  ${SUPPORT_TICKET_MESSAGE_FIELDS}
`;

export const CREATE_SUPPORT_TICKET = gql`
  mutation CreateSupportTicket($input: CreateSupportTicketInput!) {
    createSupportTicket(input: $input) {
      supportTicket {
        ...SupportTicketSummaryFields
      }
      errors
    }
  }
  ${SUPPORT_TICKET_SUMMARY_FIELDS}
`;

export const REPLY_TO_SUPPORT_TICKET = gql`
  mutation ReplyToSupportTicket($input: ReplyToSupportTicketInput!) {
    replyToSupportTicket(input: $input) {
      supportTicket {
        ...SupportTicketSummaryFields
        messages {
          ...SupportTicketMessageFields
        }
      }
      errors
    }
  }
  ${SUPPORT_TICKET_SUMMARY_FIELDS}
  ${SUPPORT_TICKET_MESSAGE_FIELDS}
`;
