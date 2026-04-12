import { Lock, MessageCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function SystemLocked() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4 relative overflow-hidden" dir="rtl">
      <div className="absolute top-[-20%] right-[-10%] w-[500px] h-[500px] rounded-full bg-destructive/10 blur-[120px]" />
      <div className="absolute bottom-[-20%] left-[-10%] w-[400px] h-[400px] rounded-full bg-destructive/5 blur-[100px]" />
      
      <div className="relative z-10 max-w-md w-full text-center space-y-6">
        <div className="mx-auto w-20 h-20 rounded-full bg-destructive/15 flex items-center justify-center">
          <Lock className="w-10 h-10 text-destructive" />
        </div>
        
        <h1 className="text-2xl font-bold text-foreground">تم قفل السيستم</h1>
        
        <div className="bg-card border border-border rounded-xl p-6 space-y-4 text-right">
          <p className="text-muted-foreground leading-relaxed">
            تم قفل السيستم من وجهة المالك فقط لحين تسديد الرسوم
            <span className="text-destructive font-bold mx-1">700 ج</span>
            متبقية من الدفعة الأولى
          </p>
          <p className="text-muted-foreground leading-relaxed">
            ويتبقى
            <span className="text-destructive font-bold mx-1">2000 ج</span>
            للشهر القادم
          </p>
        </div>
        
        <p className="text-sm text-muted-foreground">لفتح السيستم الرجاء التواصل مع الشركة</p>
        
        <Button
          className="w-full h-12 text-base font-semibold bg-green-600 hover:bg-green-700 text-white"
          onClick={() => window.open('https://wa.me/201061067966', '_blank')}
        >
          <MessageCircle className="w-5 h-5 ml-2" />
          تواصل واتساب 01061067966
        </Button>
      </div>
    </div>
  );
}
