import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function validatePassword(password: string) {
  const specialChars = /[!@#$%^&*(),.?":{}|<>]/;
  return password.length >= 8 && specialChars.test(password);
}

export function isMobile() {
  return window.innerWidth <= 768;
}

export function isSafari(): boolean {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent;
  return /^((?!chrome|android).)*safari/i.test(ua);
}

export function getGuestMessageIdKey(cardExternalId: string): string {
  return `${import.meta.env.VITE_ENV}_guestMessageId:${cardExternalId}`;
}

export function getBrandColors(): string[] {
  const styles = getComputedStyle(document.documentElement);
  return [
    styles.getPropertyValue('--color-brand-pink').trim(),
    styles.getPropertyValue('--color-brand-yellow').trim(),
    styles.getPropertyValue('--color-brand-green').trim(),
    styles.getPropertyValue('--color-brand-blue').trim(),
  ];
}
