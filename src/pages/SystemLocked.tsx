import { Lock } from 'lucide-react';
import logo from '@/assets/logo.png';

export default function SystemLocked() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4 relative overflow-hidden">
      {/* Decorative blurs */}
      <div className="absolute top-[-20%] right-[-10%] w-[500px] h-[500px] rounded-full bg-primary/10 blur-[120px]" />
      <div className="absolute bottom-[-20%] left-[-10%] w-[400px] h-[400px] rounded-full bg-primary/5 blur-[100px]" />

      <div className="relative z-10 text-center max-w-md mx-auto">
        {/* Logo */}
        <div className="mb-8">
          <img
            src={logo}
            alt="A&S Express"
            className="mx-auto h-24 w-24 rounded-2xl shadow-glow mb-4 object-cover"
          />
          <h1 className="text-3xl font-extrabold tracking-tight text-foreground">
            A&S Express
          </h1>
        </div>

        {/* Lock Icon */}
        <div className="flex justify-center mb-6">
          <div className="w-20 h-20 rounded-full bg-destructive/10 flex items-center justify-center">
            <Lock className="h-10 w-10 text-destructive" />
          </div>
        </div>

        {/* Message */}
        <h2 className="text-2xl font-bold text-foreground mb-3">
          النظام مغلق
        </h2>
        <p className="text-lg text-muted-foreground leading-relaxed">
          فترات الإيجار انتهت
        </p>
        <p className="text-sm text-muted-foreground/70 mt-2">
          يرجى التواصل مع الإدارة لتجديد الاشتراك
        </p>
      </div>
    </div>
  );
}
