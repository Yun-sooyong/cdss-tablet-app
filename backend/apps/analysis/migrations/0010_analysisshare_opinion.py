from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("analysis", "0009_batch_job_indexes"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="analysisshare",
            name="permission",
        ),
        migrations.AddField(
            model_name="analysisshare",
            name="opinion",
            field=models.CharField(blank=True, max_length=200),
        ),
    ]
