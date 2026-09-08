/**
 * The editor's GraphQL documents, co-located with the page (this repo has no
 * codegen — see docs/DEVELOPMENT.md).
 *
 * `TEMPLATE_FIELDS` pulls every coordinate the preview needs. It is a big
 * selection and that is the point: the alternative is mirroring print geometry
 * in TypeScript, where it would drift from `HolidayCardCatalogue` and take a
 * mailed card with it. One extra round trip on editor load is the cheap side of
 * that trade.
 */
import { gql } from '@apollo/client';

const TEMPLATE_FIELDS = gql`
  fragment TemplateFields on HolidayCardTemplate {
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

  fragment PanelFields on HolidayCardPanel {
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

const HOLIDAY_CARD_FIELDS = gql`
  fragment HolidayCardFields on HolidayCard {
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
 * The create flow's catalogue. Named `HolidayCardTemplates` on purpose — the API
 * treats that operation name as public, since the catalogue is reference data
 * identical for every caller.
 */
export const GET_TEMPLATES = gql`
  query HolidayCardTemplates($size: String) {
    holidayCardTemplates(size: $size) {
      ...TemplateFields
    }
  }
  ${TEMPLATE_FIELDS}
`;

/**
 * Everything the editor needs to open a card, in one round trip.
 *
 * `holidayCardMailingAvailability` is here rather than on the send flow alone
 * because the editor owns the door into it. Designing is free and works with no
 * print partner configured; offering a live "Send by post" button that leads to
 * a dead end is what this field prevents (#153).
 */
export const GET_EDITOR_DATA = gql`
  query HolidayCardEditor($externalId: String!) {
    holidayCard(externalId: $externalId) {
      ...HolidayCardFields
    }
    holidayCardMailingAvailability {
      proofsAvailable
      mailingAvailable
    }
    holidayCardTemplates {
      ...TemplateFields
    }
    holidayCardStickers {
      id
      name
      category
      dataUri
    }
    holidayCardEditorOptions {
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
  ${HOLIDAY_CARD_FIELDS}
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
  query HolidayCardOrders($externalId: String!, $holidayCardId: ID!) {
    holidayCard(externalId: $externalId) {
      externalId
      title
    }
    myHolidayCardOrders(holidayCardId: $holidayCardId) {
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
 * The dashboard's holiday tab. Counts rather than orders — see
 * `HolidayCardOrderSummaryType`; a card mailed to forty people costs five
 * integers here rather than forty rows nobody is going to read on a tile.
 *
 * The templates ride along for the thumbnail: a card with no photo yet still
 * has a template, and its background colour is enough to tell two cards apart.
 * Only the three fields the tile paints, not the full print geometry the editor
 * asks for.
 */
export const GET_DASHBOARD_HOLIDAY_CARDS = gql`
  query DashboardHolidayCards {
    myHolidayCards {
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
    holidayCardTemplates {
      id
      name
      front {
        background
      }
    }
  }
`;

/** The options alone, for the create page — it has no card to load yet. */
export const GET_EDITOR_OPTIONS = gql`
  query HolidayCardEditorOptions {
    holidayCardEditorOptions {
      cardSizes
    }
  }
`;

export const CREATE_HOLIDAY_CARD = gql`
  mutation CreateHolidayCard($size: String!, $templateId: String!, $title: String) {
    createHolidayCard(input: { size: $size, templateId: $templateId, title: $title }) {
      holidayCard {
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
export const UPDATE_HOLIDAY_CARD = gql`
  mutation UpdateHolidayCard(
    $externalId: String!
    $title: String
    $templateId: String
    $designConfig: JSON
  ) {
    updateHolidayCard(
      input: {
        externalId: $externalId
        title: $title
        templateId: $templateId
        designConfig: $designConfig
      }
    ) {
      holidayCard {
        ...HolidayCardFields
      }
      errors
    }
  }
  ${HOLIDAY_CARD_FIELDS}
`;

export const DELETE_HOLIDAY_CARD_PHOTO = gql`
  mutation DeleteHolidayCardPhoto($externalId: String!, $blobId: ID!) {
    deleteHolidayCardPhoto(input: { externalId: $externalId, blobId: $blobId }) {
      holidayCard {
        ...HolidayCardFields
      }
      errors
    }
  }
  ${HOLIDAY_CARD_FIELDS}
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
export const UPLOAD_HOLIDAY_CARD_PHOTO = `
  mutation UploadHolidayCardPhoto($input: UploadHolidayCardPhotoInput!) {
    uploadHolidayCardPhoto(input: $input) {
      photo { blobId filename contentType byteSize url }
      errors
    }
  }
`;
