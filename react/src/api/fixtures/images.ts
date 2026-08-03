import type { ImageUpload } from '@/api/types';

const B1 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930001';
const B2 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930002';
const B3 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930003';
const B4 = '3f8a1c20-9d4e-4b71-8a02-1e5c7d930004';

export const mockImages: ImageUpload[] = [
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0001',
        batch: B1,
        storage_key: `batches/${B1}/TCGA-BH-A0BL-DX1_xmin25219_ymin42847.png`,
        original_filename: 'TCGA-BH-A0BL-DX1_xmin25219_ymin42847.png',
        created_at: '2026-08-03T09:12:04.117000+09:00',
        upload_url: `https://mock-upload.local/batches/${B1}/7c2b4e91.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0002',
        batch: B2,
        storage_key: `batches/${B2}/TCGA-A2-A0T0-DX1_xmin72865_ymin59458.png`,
        original_filename: 'TCGA-A2-A0T0-DX1_xmin72865_ymin59458.png',
        created_at: '2026-08-03T10:04:19.008000+09:00',
        upload_url: `https://mock-upload.local/batches/${B2}/7c2b4e92.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0003',
        batch: B2,
        storage_key: `batches/${B2}/TCGA-LL-A73Y-DX1_xmin68117_ymin49445.png`,
        original_filename: 'TCGA-LL-A73Y-DX1_xmin68117_ymin49445.png',
        created_at: '2026-08-03T10:04:19.664000+09:00',
        upload_url: `https://mock-upload.local/batches/${B2}/7c2b4e93.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0004',
        batch: B3,
        storage_key: `batches/${B3}/TCGA-E2-A1LS-DX1_xmin39247_ymin47756.png`,
        original_filename: 'TCGA-E2-A1LS-DX1_xmin39247_ymin47756.png',
        created_at: '2026-08-02T14:31:08.551000+09:00',
        upload_url: `https://mock-upload.local/batches/${B3}/7c2b4e94.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0005',
        batch: B3,
        storage_key: `batches/${B3}/TCGA-A2-A3XS-DX1_xmin21421_ymin37486.png`,
        original_filename: 'TCGA-A2-A3XS-DX1_xmin21421_ymin37486.png',
        created_at: '2026-08-02T14:31:09.204000+09:00',
        upload_url: `https://mock-upload.local/batches/${B3}/7c2b4e95.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0006',
        batch: B3,
        storage_key: `batches/${B3}/TCGA-A2-A0D0-DX1_xmin68482_ymin39071.png`,
        original_filename: 'TCGA-A2-A0D0-DX1_xmin68482_ymin39071.png',
        created_at: '2026-08-02T14:31:09.870000+09:00',
        upload_url: `https://mock-upload.local/batches/${B3}/7c2b4e96.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0007',
        batch: B3,
        storage_key: `batches/${B3}/TCGA-A2-A0ST-DX1_xmin109446_ymin18274.png`,
        original_filename: 'TCGA-A2-A0ST-DX1_xmin109446_ymin18274.png',
        created_at: '2026-08-02T14:31:10.462000+09:00',
        upload_url: `https://mock-upload.local/batches/${B3}/7c2b4e97.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0008',
        batch: B3,
        storage_key: `batches/${B3}/TCGA-BH-A18Q-DX1_xmin14038_ymin52190.png`,
        original_filename: 'TCGA-BH-A18Q-DX1_xmin14038_ymin52190.png',
        created_at: '2026-08-02T14:31:11.019000+09:00',
        upload_url: `https://mock-upload.local/batches/${B3}/7c2b4e98.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0009',
        batch: B3,
        storage_key: `batches/${B3}/TCGA-D8-A1J8-DX1_xmin83610_ymin27455.png`,
        original_filename: 'TCGA-D8-A1J8-DX1_xmin83610_ymin27455.png',
        created_at: '2026-08-02T14:31:11.733000+09:00',
        upload_url: `https://mock-upload.local/batches/${B3}/7c2b4e99.png`,
    },
    {
        id: '7c2b4e91-5a63-4d08-9f14-2b8e6a1c0010',
        batch: B4,
        storage_key: `batches/${B4}/TCGA-AR-A1AS-DX1_xmin40912_ymin61033.png`,
        original_filename: 'TCGA-AR-A1AS-DX1_xmin40912_ymin61033.png',
        created_at: '2026-08-01T16:47:53.290000+09:00',
        upload_url: `https://mock-upload.local/batches/${B4}/7c2b4e10.png`,
    },
];
