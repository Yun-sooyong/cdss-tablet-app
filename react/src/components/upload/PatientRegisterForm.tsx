import { useState } from 'react';
import type { ReactNode } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { registerPatient } from '@/api';
import { qk } from '@/api/keys';
import type { PatientSummary, Sex } from '@/api/types';
import { BUTTON_PRIMARY, BUTTON_SECONDARY, FIELD_INPUT } from '@/components/form';
import { SEX_LABEL, patientFull } from '@/lib/patient';

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

    const canSubmit = !!name.trim() && !!birthDate && !!phone.trim();
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
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
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
