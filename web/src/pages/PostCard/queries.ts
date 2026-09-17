/**
 * The editor's GraphQL documents, co-located with the page (this repo has no
 * codegen — see docs/DEVELOPMENT.md).
 *
 * `TEMPLATE_FIELDS` pulls every coordinate the preview needs. It is a big
 * selection and that is the point: the alternative is mirroring print geometry
 * in TypeScript, where it would drift from `PostCardCatalogue` and take a
 * mailed card with it. One extra round trip on editor load is the cheap side of
 * that trade.
 */
import { gql } from '@apollo/client';

const TEMPLATE_FIELDS = gql`
  fragment TemplateFields on PostCardTemplate {
    id
    name
    description
    size
    widthInches
    heightInches
    bleedInches
    safeMarginInches
    bleedBox {
      x
      y
      w
      h
    }
    safeBox {
      x
      y
      w
      h
    }
    reservedAddressBlock {
      x
      y
      w
      h
    }
    front {
      ...PanelFields
    }
    back {
      ...PanelFields
    }
  }

  fragment PanelFields on PostCardPanel {
    name
    background
    photoSlots {
      id
      radius
      rect {
        x
        y
        w
        h
      }
    }
    textRegions {
      id
      align
      defaultFont
      defaultSize
      rect {
        x
        y
        w
        h
      }
    }
    stickerRegions {
      id
      rect {
        x
        y
        w
        h
      }
    }
  }
`;

const POST_CARD_FIELDS = gql`
  fragment PostCardFields on PostCard {
    id
    externalId
    title
    size
    templateId
    designConfig
    updatedAt
    photos {
      blobId
      filename
      contentType
      byteSize
      url
    }
  }
`;

/**
 * The create flow's catalogue. Named `PostCardTemplates` on purpose — the API
 * treats that operation name as public, since the catalogue is reference data
 * identical for every caller.
 */
export const GET_TEMPLATES = gql`
  query PostCardTemplates($size: String) {
    postCardTemplates(size: $size) {
      ...TemplateFields
    }
  }
  ${TEMPLATE_FIELDS}
`;

/**
 * Everything the editor needs to open a card, in one round trip.
 *
 * `postCardMailingAvailability` is here rather than on the send flow alone
 * because the editor owns the door into it. Designing is free and works with no
 * print partner configured; offering a live "Send by post" button that leads to
 * a dead end is what this field prevents (#153).
 */
export const GET_EDITOR_DATA = gql`
  query PostCardEditor($externalId: String!) {
    postCard(externalId: $externalId) {
      ...PostCardFields
    }
    postCardMailingAvailability {
      proofsAvailable
      mailingAvailable
    }
    postCardTemplates {
      ...TemplateFields
    }
    postCardStickers {
      id
      name
      category
      dataUri
    }
    postCardEditorOptions {
      designConfigVersion
      cardSizes
      fonts {
        key
        name
        fallback
      }
      textSizes {
        key
        points
      }
      alignments
      lineHeight
      textMaxLength
      minZoom
      maxZoom
      maxPan
      maxPhotos
    }
  }
  ${POST_CARD_FIELDS}
  ${TEMPLATE_FIELDS}
`;

/**
 * The orders page (#153): the card's name, and one row per piece mailed.
 *
 * The card comes along so the page can say *which* card these went out as,
 * rather than heading a list of forty addresses with nothing to identify it.
 * `recipientAddress` is the order's own snapshot, not the contact's — a contact
 * edited since is not where the card went, and this page's whole job is saying
 * where it went.
 */
export const GET_ORDERS = gql`
  query PostCardOrders($externalId: String!, $postCardId: ID!) {
    postCard(externalId: $externalId) {
      externalId
      title
    }
    myPostCardOrders(postCardId: $postCardId) {
      id
      status
      chargedCents
      recipientName
      recipientAddress {
        name
        addressLine1
        addressLine2
        city
        region
        postalCode
        countryCode
      }
      contactId
      trackingNumber
      failureReason
      submittedAt
      mailedAt
      createdAt
    }
  }
`;

/**
 * The dashboard's post card tab. Counts rather than orders — see
 * `PostCardOrderSummaryType`; a card mailed to forty people costs five
 * integers here rather than forty rows nobody is going to read on a tile.
 *
 * The templates ride along for the thumbnail: a card with no photo yet still
 * has a template, and its background colour is enough to tell two cards apart.
 * Only the three fields the tile paints, not the full print geometry the editor
 * asks for.
 */
export const GET_DASHBOARD_POST_CARDS = gql`
  query DashboardPostCards {
    myPostCards {
      externalId
      title
      size
      templateId
      updatedAt
      photos {
        url
      }
      orderSummary {
        total
        inFlight
        delivered
        failed
        lastOrderedAt
      }
    }
    postCardTemplates {
      id
      name
      front {
        background
      }
    }
  }
`;

/**
 * Delete a post card that has never been mailed (#205). The server refuses a
 * card with orders against it, so `errors` is the message to show — the
 * dashboard only offers this on unsent cards, but the check that matters is
 * there and not here.
 */
export const DELETE_POST_CARD = gql`
  mutation DeletePostCard($externalId: String!) {
    deletePostCard(input: { externalId: $externalId }) {
      success
      errors
    }
  }
`;

/** The options alone, for the create page — it has no card to load yet. */
export const GET_EDITOR_OPTIONS = gql`
  query PostCardEditorOptions {
    postCardEditorOptions {
      cardSizes
    }
  }
`;

export const CREATE_POST_CARD = gql`
  mutation CreatePostCard($size: String!, $templateId: String!, $title: String) {
    createPostCard(input: { size: $size, templateId: $templateId, title: $title }) {
      postCard {
        externalId
      }
      errors
    }
  }
`;

/**
 * The autosave. `designConfig` replaces the stored document wholesale, so the
 * editor sends the whole thing every time; `templateId` rides along on the same
 * save as the re-mapped document, so a layout switch is never half-applied.
 */
export const UPDATE_POST_CARD = gql`
  mutation UpdatePostCard(
    $externalId: String!
    $title: String
    $templateId: String
    $designConfig: JSON
  ) {
    updatePostCard(
      input: {
        externalId: $externalId
        title: $title
        templateId: $templateId
        designConfig: $designConfig
      }
    ) {
      postCard {
        ...PostCardFields
      }
      errors
    }
  }
  ${POST_CARD_FIELDS}
`;

export const DELETE_POST_CARD_PHOTO = gql`
  mutation DeletePostCardPhoto($externalId: String!, $blobId: ID!) {
    deletePostCardPhoto(input: { externalId: $externalId, blobId: $blobId }) {
      postCard {
        ...PostCardFields
      }
      errors
    }
  }
  ${POST_CARD_FIELDS}
`;

/**
 * Sent as a multipart request by `uploadGraphQLMutation`, not through Apollo —
 * `apollo-upload-client` is not a dependency, so file-carrying mutations bypass
 * the client. Hence a plain string rather than a `gql` document.
 *
 * It takes a single `$input` variable rather than one variable per argument
 * because that is the shape the helper builds: it posts
 * `variables: { input }` and maps the file to `variables.input.photoFile`.
 * Spelling the arguments out individually makes the server reject both
 * variables as "provided invalid value".
 */
export const UPLOAD_POST_CARD_PHOTO = `
  mutation UploadPostCardPhoto($input: UploadPostCardPhotoInput!) {
    uploadPostCardPhoto(input: $input) {
      photo { blobId filename contentType byteSize url }
      errors
    }
  }
`;
