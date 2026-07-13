import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Score, RankLevel } from '../entities/score.entity';
import { PointLog } from '../entities/point-log.entity';

@Injectable()
export class ReputationService {
  constructor(
    @InjectRepository(Score) private readonly scoreRepo: Repository<Score>,
    @InjectRepository(PointLog)
    private readonly pointLogRepo: Repository<PointLog>,
  ) {}

  /**
   * Cộng/trừ điểm tín nhiệm. Idempotent nếu truyền [idempotentKey]
   * (so khớp reasonCode + note chứa key).
   */
  async adjustPoints(
    userId: number,
    delta: number,
    reasonCode: string,
    note: string,
    opts?: { idempotentKey?: string; min?: number; max?: number },
  ): Promise<{ trustScore: number; rankLevel: RankLevel; applied: boolean }> {
    if (delta === 0) {
      const score = await this.ensureScore(userId);
      return {
        trustScore: score.currentPoint,
        rankLevel: score.rankLevel,
        applied: false,
      };
    }

    if (opts?.idempotentKey) {
      const existing = await this.pointLogRepo
        .createQueryBuilder('p')
        .where('p.userId = :userId', { userId })
        .andWhere('p.reasonCode = :code', { code: reasonCode })
        .andWhere('p.note LIKE :key', { key: `%${opts.idempotentKey}%` })
        .getOne();
      if (existing) {
        const score = await this.ensureScore(userId);
        return {
          trustScore: score.currentPoint,
          rankLevel: score.rankLevel,
          applied: false,
        };
      }
    }

    const score = await this.ensureScore(userId);
    const min = opts?.min ?? 0;
    const max = opts?.max ?? 1000;
    const next = Math.min(max, Math.max(min, score.currentPoint + delta));
    score.currentPoint = next;
    score.rankLevel = this.rankFor(next);
    await this.scoreRepo.save(score);
    await this.pointLogRepo.save({
      userId,
      delta,
      reasonCode,
      note,
    });

    return {
      trustScore: next,
      rankLevel: score.rankLevel,
      applied: true,
    };
  }

  async ensureScore(userId: number): Promise<Score> {
    let score = await this.scoreRepo.findOne({ where: { userId } });
    if (!score) {
      score = this.scoreRepo.create({
        userId,
        currentPoint: 500,
        rankLevel: 'Bronze',
      });
      score = await this.scoreRepo.save(score);
    }
    return score;
  }

  rankFor(point: number): RankLevel {
    if (point >= 850) return 'Diamond';
    if (point >= 600) return 'Gold';
    if (point >= 300) return 'Silver';
    return 'Bronze';
  }
}
