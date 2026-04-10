import 'package:flutter_app/models/data.dart';

AppData buildSampleData() {
  return AppData(
    workspaceId: 'default',
    workspaceName: 'Card Bookkeeping',
    persons: <String>['星河', '石'],
    recentPickAmounts: <double>[20, 50],
    batches: <Batch>[
      Batch(
        id: 'batch-1',
        workspaceId: 'default',
        name: 'A 批次',
        rate: 4.0,
        batchDate: '2026-04-09',
        createdAt: 1,
        updatedAt: 2,
        cards: <CardItem>[
          CardItem(id: 'c-1', label: '1001', secret: 'aaa', face: 10),
          CardItem(id: 'c-2', label: '1002', secret: 'bbb', face: 10, status: CardStatus.picked, statusBy: '星河', statusAt: 3),
          CardItem(id: 'c-3', label: '1003', secret: 'ccc', face: 20, status: CardStatus.bad, actualBalance: 5, statusBy: '石', statusAt: 4),
        ],
      ),
      Batch(
        id: 'batch-2',
        workspaceId: 'default',
        name: 'B 批次',
        rate: 4.2,
        batchDate: '2026-04-08',
        createdAt: 5,
        updatedAt: 6,
        cards: <CardItem>[
          CardItem(id: 'c-4', label: '2001', secret: 'ddd', face: 50),
          CardItem(id: 'c-5', label: '2002', secret: 'eee', face: 25),
        ],
      ),
    ],
    activities: <ActivityLog>[
      ActivityLog(id: 'a-1', type: 'pick', summary: '提卡 1 张，金额 10', actor: '星河', createdAt: 6),
    ],
    updatedAt: 6,
  );
}
