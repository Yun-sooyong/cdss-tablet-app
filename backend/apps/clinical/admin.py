from django.contrib import admin

from .models import (
    Diagnosis,
    Disease,
    DoseLog,
    DoseSchedule,
    Drug,
    Prescription,
    PrescriptionDrug,
    Reservation,
    ReservationHistory,
    Visit,
)

admin.site.register(Reservation)
admin.site.register(ReservationHistory)
admin.site.register(Disease)
admin.site.register(Visit)
admin.site.register(Diagnosis)
admin.site.register(Drug)
admin.site.register(Prescription)
admin.site.register(PrescriptionDrug)
admin.site.register(DoseSchedule)
admin.site.register(DoseLog)
