clc; clear; close all;

%% 1. خواندن فایل صوتی نویزی
[y_noisy, Fs] = audioread('noisy_voice.wav');

% پارامترهای فریم‌بندی (Framing)
frame_duration = 0.025; % طول هر فریم: 25 میلی‌ثانیه (استاندارد پردازش گفتار)
frame_len = floor(frame_duration * Fs); % تبدیل زمان به تعداد نمونه
overlap = 0.5; % میزان همپوشانی فریم‌ها (50 درصد)
step_len = floor(frame_len * (1 - overlap)); % گام حرکت پنجره

% پنجره همینگ برای کاهش نشت طیفی (Spectral Leakage)
window = hamming(frame_len);

%% 2. تخمین نویز (Noise Estimation)
% فرض می‌کنیم 0.25 ثانیه اول فایل فقط نویز است (هنوز صحبت شروع نشده)
% در فایل handel.mat معمولا اولش سکوت نیست، اما چون نویز سفید اضافه کردیم
% میانگین نویز در کل فایل ثابت است. پس از تکه اول برای تخمین استفاده می‌کنیم.
noise_frames_count = 10; 
noise_energy = zeros(frame_len, 1);

% محاسبه انرژی نویز از چند فریم اول
for i = 1:noise_frames_count
    frame = y_noisy((i-1)*step_len + 1 : (i-1)*step_len + frame_len);
    % اعمال پنجره و گرفتن FFT
    frame_fft = fft(frame .* window);
    % جمع انرژی (قدر مطلق)
    noise_energy = noise_energy + abs(frame_fft);
end

% میانگین‌گیری از طیف نویز
mean_noise_spectrum = noise_energy / noise_frames_count;

%% 3. حلقه اصلی پردازش (Spectral Subtraction)
y_cleaned = zeros(length(y_noisy), 1);
num_frames = floor((length(y_noisy) - frame_len) / step_len);
count_overlap = zeros(length(y_noisy), 1); % برای نرمال‌سازی Overlap-Add

for i = 1:num_frames
    % استخراج فریم جاری
    idx_start = (i-1)*step_len + 1;
    idx_end = idx_start + frame_len - 1;
    noisy_frame = y_noisy(idx_start : idx_end);
    
    % الف) رفتن به حوزه فرکانس
    noisy_fft = fft(noisy_frame .* window);
    
    % ب) تفریق طیفی (Magnitude Subtraction)
    % دامنه سیگنال تمیز = دامنه نویزی - میانگین نویز
    clean_mag = abs(noisy_fft) - 2.0 * mean_noise_spectrum; 
    
    % ج) حذف مقادیر منفی (چون دامنه نمی‌تواند منفی باشد)
    clean_mag(clean_mag < 0) = 0; 
    
    % د) بازسازی سیگنال (استفاده از فاز سیگنال نویزی)
    % فاز را از سیگنال نویزی قرض می‌گیریم (چون گوش انسان به فاز حساس نیست)
    phase = angle(noisy_fft);
    clean_fft = clean_mag .* exp(1j * phase);
    
    % ه) برگشت به حوزه زمان (IFFT)
    clean_frame = real(ifft(clean_fft));
    
    % و) روش Overlap-Add (جمع کردن فریم‌ها سر جای خودشان)
    y_cleaned(idx_start : idx_end) = y_cleaned(idx_start : idx_end) + clean_frame;
    count_overlap(idx_start : idx_end) = count_overlap(idx_start : idx_end) + window; 
end

%% 4. نهایی‌سازی خروجی
% جلوگیری از تقسیم بر صفر در جاهایی که پنجره نبوده
count_overlap(count_overlap < 1e-5) = 1; 
y_cleaned = y_cleaned ./ count_overlap;

% ذخیره فایل تمیز شده
audiowrite('cleaned_voice_output.wav', y_cleaned, Fs);

%% 5. نمایش نتایج و پخش
figure;
subplot(3,1,1); plot(y_noisy); title('Noisy Input'); grid on; axis tight;
subplot(3,1,2); plot(y_cleaned); title('Cleaned Output (Spectral Subtraction)'); grid on; axis tight;

% رسم اسپکتروگرام برای دیدن حذف نویز در فرکانس‌ها
subplot(3,1,3); 
spectrogram(y_cleaned, 256, 128, 256, Fs, 'yaxis'); 
title('Spectrogram of Cleaned Signal');

disp('Playing Noisy Signal...');
sound(y_noisy, Fs);
pause(length(y_noisy)/Fs + 1);

disp('Playing Cleaned Signal...');
sound(y_cleaned, Fs);