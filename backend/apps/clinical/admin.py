from django.contrib import admin

from .models import Diagnosis, Disease, Reservation, ReservationHistory, Visit

admin.site.register(Reservation)
admin.site.register(ReservationHistory)
admin.site.register(Disease)
admin.site.register(Visit)
admin.site.register(Diagnosis)
