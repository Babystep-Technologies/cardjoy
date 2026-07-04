# Product Requirements Document (PRD) for CardJoy V1

## Executive Summary
CardJoy is a digital card platform designed for creating and sharing e-cards for various occasions such as birthdays, farewells, and welcomes. It simplifies group participation by allowing multiple contributors to add personalized messages and pictures to a shared card. The platform monetizes through a credit system, with one credit enabling the creation of one card. Future opportunities include a marketplace for card themes and gift card integration.

---

## Goals and Objectives
### Goals:
1. Launch an intuitive and user-friendly digital card platform.
2. Validate the business model with a credit-based monetization system.
3. Provide a delightful experience for card creators, contributors, and recipients.

### Objectives for V1:
- Allow users to create, customize, and share e-cards.
- Facilitate easy contribution to cards via a shared link.
- Offer polished recipient experiences with pre-designed themes.
- Introduce an admin interface for platform management.

---

## Target Audience
1. **Individuals** organizing group cards for occasions like birthdays, farewells, and team welcomes.
2. **Small Teams** looking for an easy way to collect messages and pictures for group cards.
3. **Recipients** who value visually appealing and personalized digital cards.

---

## Core Features
### User Onboarding
- Sign-up and login functionality via email/password.
- OAuth login integration (Google).

### Card Creation
- Select from 5 pre-designed templates (e.g., birthday, farewell, welcome).
- Customize cards with:
  - Text messages.
  - Attached pictures.
- Generate a shareable link for contributors.

### Contributor Experience
- Access the card via a shared link.
- Add messages (text and pictures).
- View the selected template but cannot change it.
- No sign-up required for contribution.

### Recipient View
- Access the completed card via a unique link.
- View all contributions in a visually appealing format.
- Option to download or save the card.

### Monetization
- Credit-based system:
  - $1 per credit, one credit creates one card.
- Payment gateway integration (Stripe/PayPal).

### Admin Interface
- Integrated into the main product backend.
- Features:
  - Manage user accounts (create, suspend, delete).
  - Track credit purchases and transactions.
  - Monitor card activity (created, active, finalized).
  - Resolve disputes (e.g., refund requests).
  - Basic analytics (e.g., total users, cards created, credits sold).

---

## Non-Core Features for Future Versions
1. **Gift Card Integration**:
   - Allow users to purchase gift cards (e.g., Amazon).
   - Explore monetization through affiliate links or commissions.

2. **Theme Marketplace**:
   - Enable creators to design and sell custom templates.
   - Revenue share model for theme creators.

3. **Advanced Animations**:
   - Add special effects to cards (e.g., animations, transitions).

---

## User Workflows
### Card Creator Workflow:
1. Log in/sign up.
2. Select a card occasion and template.
3. Add a message (text and pictures).
4. Generate a shareable link for contributors.
5. Purchase a credit to finalize the card.
6. Share the recipient link for viewing the card.

### Contributor Workflow:
1. Open the shared link.
2. Add a message (text and optional picture).
3. Submit the message without needing to sign up.

### Recipient Workflow:
1. Open the recipient link.
2. View all contributions in a clean, user-friendly format.
3. Optionally download or save the card.

### Admin Workflow:
1. Log into the admin interface.
2. Perform management tasks:
   - View/edit user accounts.
   - Monitor transactions and card activity.
   - Resolve disputes.
   - Review platform analytics.

---

## Technical Requirements
### Frontend
- **Framework**: React/TypeScript.
- **UI Library**: Material-UI (MUI) with react-spring for animations.
- **Responsiveness**: Mobile-first design.

### Backend
- **Framework**: Ruby on Rails.
- **Database**: DynamoDB for scalability.
- **Authentication**: OAuth 2.0 integration.
- **Payments**: Stripe/PayPal for credit purchases.

### Admin Interface
- Built as part of the main backend with a web-based UI.

### Deployment
- **Hosting**: AWS or similar cloud provider.
- **CI/CD**: Automated pipelines for testing and deployment.

---

## Design Considerations
- Templates should be easily extendable.
- Ensure intuitive workflows for all user types.
- Maintain a clean, modern aesthetic aligned with the brand.

---

## Timeline and Milestones
1. **Month 1**: Define detailed designs and wireframes.
2. **Month 2-3**: Develop core features (onboarding, card creation, contributions, recipient view).
3. **Month 4**: Integrate payments and admin interface.
4. **Month 5**: Testing and QA.
5. **Month 6**: Launch V1.

---

## Risks and Dependencies
### Risks
- Potential user friction with credit-based monetization.
- Managing scalability during high traffic periods.

### Dependencies
- Third-party services: OAuth, payment gateways, hosting provider.
- Availability of a small team for testing and feedback.

---

## Future Vision
As CardJoy grows, we envision expanding the platform to include:
- A thriving theme marketplace.
- Advanced card animations and effects.
- Deeper monetization options through gift card integrations.

---


