import GoogleLoginButton from '@/components/GoogleLoginButton';

export default function AdminSignInPage() {
  return (
    <div className="flex min-h-screen w-screen items-center justify-center bg-background text-foreground">
      <div className="w-full max-w-md bg-white shadow-lg rounded-xl p-8 space-y-6 text-center">
        <div className="space-y-2">
          <div className="flex flex-col items-center justify-center">
            <img src="/font-logo.svg" alt="CardJoy" className="w-28 h-auto mb-2" />
            <h1 className="text-xl font-semibold text-black tracking-tight">Admin</h1>
          </div>
          <p className="text-gray-600 text-sm">
            Please use your authorized Google account to access the admin dashboard.
          </p>
        </div>

        <GoogleLoginButton />

        <p className="text-xs text-muted-foreground mt-4">
          Only authorized admin accounts will be granted access.
        </p>
      </div>
    </div>
  );
}
