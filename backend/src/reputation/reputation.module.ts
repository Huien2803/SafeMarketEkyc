import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Score } from '../entities/score.entity';
import { PointLog } from '../entities/point-log.entity';
import { ReputationService } from './reputation.service';

@Module({
  imports: [TypeOrmModule.forFeature([Score, PointLog])],
  providers: [ReputationService],
  exports: [ReputationService],
})
export class ReputationModule {}
