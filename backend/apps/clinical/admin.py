from django.contrib import admin

from .models import Reservation, ReservationHistory

admin.site.register(Reservation)
admin.site.register(ReservationHistory)
