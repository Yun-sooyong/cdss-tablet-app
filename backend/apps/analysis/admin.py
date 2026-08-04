from django.contrib import admin

from .models import AnalysisShare, Batch, Image, Job, ModelVersion, WorkerHeartbeat

admin.site.register(Batch)
admin.site.register(Image)
admin.site.register(Job)
admin.site.register(ModelVersion)
admin.site.register(AnalysisShare)
admin.site.register(WorkerHeartbeat)
