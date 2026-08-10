import { useState } from 'react';
import type { ReactNode } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { registerPatient } from '@/api';
import { qk } from '@/api/keys';
import type { PatientSummary, Sex } from '@/api/types';
import { BUTTON_PRIMARY, BUTTON_SECONDARY, FIELD_INPUT } from '@/components/form';
import { SEX_LABEL, patientFull } from '@/lib/patient';

const TODAY = new Date().toISOString().slice(0, 10);

// PatientRegisterForm
export function PatientRegisterForm({
    onCancel,
    onCreated,
} : {
    onCancel : () => void;
    onCreated : (patient : PatientSummary) => void;
}) {
    const queryClient = useQueryClient();

    const [name, setName] = useState('');
    const [birthDate, setBirthDate] = useState('');
    const [sex, setSex] = useState<Sex>('U');
    const [phone, setPhone] = useState('');

    // 숫자만 남기고 010-0000-0000 꼴로 끊는다. 11자리를 넘기면 더 받지 않는다
    function formatPhone(next : string) : string {
        const digits = next.replace(/\D/g, '').slice(0, 11);
        if (digits.length < 4) return digits;
        if (digits.length < 8) return `${digits.slice(0, 3)}-${digits.slice(3)}`;
        return `${digits.slice(0, 3)}-${digits.slice(3, 7)}-${digits.slice(7)}`;
    }

    const phoneDigits = phone.replace(/\D/g, '');
    const phoneValid = phoneDigits.length === 10 || phoneDigits.length === 11;
    // 태어나지 않은 날짜와 6자리 연도를 막는다
    const birthValid = !!birthDate && birthDate >= '1900-01-01' && birthDate <= TODAY;

    const canSubmit = !!name.trim() && birthValid && phoneValid;
    const dirty = !!name.trim() || !!birthDate || !!phone.trim();

    const register = useMutation({
        mutationFn: () =>
            registerPatient({
                name: name.trim(),
                birth_date: birthDate,
                sex,
                phone: phone.trim(),
            }),
        onSuccess: (created) => {
            void queryClient.invalidateQueries({ queryKey: qk.patients });
            toast.success('환자를 등록했습니다', { description: patientFull(created) });
            onCreated(created);
        },
        onError: (error : Error) =>
            toast.error('환자를 등록하지 못했습니다', { description: error.message }),
    });

    function cancel() {
        if (dirty && !window.confirm('입력한 내용이 사라집니다.')) return;
        onCancel();
    }

    return (
        <form
            onSubmit={(e) => {
                e.preventDefault();
                register.mutate();
            }}
            className="space-y-3"
        >
            <LabelledField label="이름">
                <input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className={FIELD_INPUT}
                />
            </LabelledField>

            <div className="grid grid-cols-2 gap-3">
                <LabelledField label="생년월일">
                    <input
                        type="date"
                        value={birthDate}
                        onChange={(e) => setBirthDate(e.target.value)}
                        min="1900-01-01"
                        max={TODAY}
                        className={FIELD_INPUT}
                    />
                </LabelledField>

                <LabelledField label="성별">
                    <select
                        value={sex}
                        onChange={(e) => setSex(e.target.value as Sex)}
                        className={FIELD_INPUT}
                    >
                        {(Object.entries(SEX_LABEL) as [Sex, string][]).map(
                            ([value, label]) => (
                                <option key={value} value={value}>
                                    {label}
                                </option>
                            ),
                        )}
                    </select>
                </LabelledField>
            </div>

            <LabelledField label="전화번호">
                <input
                    type="tel"
                    inputMode="numeric"
                    value={phone}
                    onChange={(e) => setPhone(formatPhone(e.target.value))}
                    placeholder="010-0000-0000"
                    className={FIELD_INPUT}
                />
            </LabelledField>

            <div className="flex gap-2 pt-1">
                <button
                    type="submit"
                    disabled={!canSubmit || register.isPending}
                    className={BUTTON_PRIMARY}
                >
                    등록
                </button>
                <button type="button" onClick={cancel} className={BUTTON_SECONDARY}>
                    취소
                </button>
            </div>
        </form>
    );
}

function LabelledField({ label, children } : { label : string; children : ReactNode }) {
    return (
        <label className="block">
            <span className="mb-1.5 block text-sm text-ink-muted">{label}</span>
            {children}
        </label>
    );
}
