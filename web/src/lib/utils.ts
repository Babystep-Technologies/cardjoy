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

export function getInitials(name?: string | null, email?: string | null): string {
  const source = name?.trim() || email?.trim() || '';
  if (!source) return '?';
  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  return source.slice(0, 2).toUpperCase();
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
