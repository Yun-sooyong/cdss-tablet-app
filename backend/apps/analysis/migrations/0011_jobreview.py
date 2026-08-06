import uuid

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("analysis", "0010_analysisshare_opinion"),
        ("staff", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="JobReview",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "decision",
                    models.CharField(
                        choices=[("LOW", "낮음"), ("HIGH", "높음")], max_length=10
                    ),
                ),
                ("reason", models.TextField()),
                (
                    "job",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="reviews",
                        to="analysis.job",
                    ),
                ),
                (
                    "reviewed_by",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name="job_reviews",
                        to="staff.staff",
                    ),
                ),
            ],
            options={
                "db_table": "job_review",
                "ordering": ["-created_at"],
            },
        ),
    ]
