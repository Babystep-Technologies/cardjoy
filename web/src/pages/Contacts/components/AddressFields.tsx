import React, { useState } from 'react';
import { MapPin } from 'lucide-react';

import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  COUNTRY_CODE_OPTIONS,
  type AddressDraft,
  type AddressErrors,
  type CountryCode,
} from '@/lib/address';

type AddressFieldsProps = {
  value: AddressDraft;
  /** Partial so the parent can apply it against the latest state, not this render's copy. */
  onChange: (patch: Partial<AddressDraft>) => void;
  errors: AddressErrors;
  /** Open the section on mount — used when editing a contact that already has an address. */
  defaultOpen?: boolean;
};

const SECTION_VALUE = 'mailing-address';

// Postal fields are one-line and short; the grid keeps them from each eating a full row.
const AddressFields: React.FC<AddressFieldsProps> = ({
  value,
  onChange,
  errors,
  defaultOpen = false,
}) => {
  const [openSection, setOpenSection] = useState(defaultOpen ? SECTION_VALUE : '');

  // An error anywhere inside a collapsed section is invisible, so force it open.
  const hasErrors = Object.keys(errors).length > 0;
  const open = hasErrors ? SECTION_VALUE : openSection;

  const fieldError = (field: keyof AddressDraft) =>
    errors[field] ? (
      <p className="text-sm text-red-600" role="alert">
        {errors[field]}
      </p>
    ) : null;

  return (
    <Accordion type="single" collapsible value={open} onValueChange={setOpenSection}>
      <AccordionItem value={SECTION_VALUE} className="border-t border-b-0 pt-1">
        <AccordionTrigger className="py-3 hover:no-underline">
          <span className="flex items-center gap-2 text-sm font-medium text-gray-800">
            <MapPin className="h-4 w-4 text-pink-500" />
            Mailing address
            <span className="font-normal text-gray-500">— for printed cards</span>
          </span>
        </AccordionTrigger>
        <AccordionContent className="space-y-4 pb-2">
          <div className="space-y-1.5">
            <Label htmlFor="contact-address-line1">Street address</Label>
            <Input
              id="contact-address-line1"
              autoComplete="address-line1"
              value={value.line1}
              onChange={e => onChange({ line1: e.target.value })}
              aria-invalid={!!errors.line1 || undefined}
              placeholder="12 Elm Street"
            />
            {fieldError('line1')}
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="contact-address-line2">Apartment, suite, etc.</Label>
            <Input
              id="contact-address-line2"
              autoComplete="address-line2"
              value={value.line2}
              onChange={e => onChange({ line2: e.target.value })}
              placeholder="Apt 4B"
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="contact-address-city">City</Label>
              <Input
                id="contact-address-city"
                autoComplete="address-level2"
                value={value.city}
                onChange={e => onChange({ city: e.target.value })}
                aria-invalid={!!errors.city || undefined}
                placeholder="Austin"
              />
              {fieldError('city')}
            </div>
            <div className="space-y-1.5">
              {/* "Region", not "State" — plenty of countries have neither. */}
              <Label htmlFor="contact-address-region">State / region</Label>
              <Input
                id="contact-address-region"
                autoComplete="address-level1"
                value={value.region}
                onChange={e => onChange({ region: e.target.value })}
                placeholder="TX"
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="contact-address-postal-code">Postal code</Label>
              <Input
                id="contact-address-postal-code"
                autoComplete="postal-code"
                value={value.postalCode}
                onChange={e => onChange({ postalCode: e.target.value })}
                aria-invalid={!!errors.postalCode || undefined}
                placeholder="78701"
              />
              {fieldError('postalCode')}
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="contact-address-country">Country</Label>
              {/* A select, not free text, so `countryCode` stays a valid ISO 3166-1 alpha-2
                  code — the form every mail vendor speaks. */}
              <Select
                value={value.countryCode}
                onValueChange={next => onChange({ countryCode: next as CountryCode })}
              >
                <SelectTrigger id="contact-address-country" className="w-full">
                  <SelectValue placeholder="Pick a country" />
                </SelectTrigger>
                <SelectContent className="max-h-72">
                  {COUNTRY_CODE_OPTIONS.map(option => (
                    // The list is ~240 long; Radix's type-ahead matches the rendered text,
                    // which starts with a flag emoji, so point it at the name instead.
                    <SelectItem key={option.code} value={option.code} textValue={option.name}>
                      {option.flag} {option.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {fieldError('countryCode')}
            </div>
          </div>

          <p className="text-xs text-gray-500">
            Leave this blank if you only send digital cards. Once you start an address, street
            address, city, postal code and country are all needed to deliver it.
          </p>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  );
};

export default AddressFields;
