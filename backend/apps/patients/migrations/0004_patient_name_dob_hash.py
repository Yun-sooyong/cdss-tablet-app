import hashlib

from django.db import migrations, models


def compute_name_dob_hash(apps, schema_editor):
    Patient = apps.get_model("patients", "Patient")
    for patient in Patient.objects.all():
        name = (patient.name or "").strip()
        dob = patient.birth_date.isoformat() if patient.birth_date else ""
        patient.name_dob_hash = hashlib.sha256(f"{name}|{dob}".encode()).hexdigest()
        patient.save(update_fields=["name_dob_hash"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("patients", "0003_alter_patient_user"),
    ]

    operations = [
        migrations.AddField(
            model_name="patient",
            name="name_dob_hash",
            field=models.CharField(db_index=True, editable=False, max_length=64, default=""),
            preserve_default=False,
        ),
        migrations.RunPython(compute_name_dob_hash, noop),
    ]
