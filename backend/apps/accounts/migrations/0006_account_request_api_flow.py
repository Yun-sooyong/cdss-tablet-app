from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0005_accountrequest"),
    ]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="type",
            field=models.CharField(
                choices=[
                    ("analysis_done", "분석 완료"),
                    ("share", "공유"),
                    ("chat", "채팅"),
                    ("reservation_confirmed", "예약 확정"),
                    ("visit_created", "진료 기록 등록"),
                    ("prescription_created", "처방 등록"),
                    ("account_request", "계정 발급 요청"),
                ],
                max_length=30,
            ),
        ),
        migrations.DeleteModel(
            name="Invitation",
        ),
    ]
