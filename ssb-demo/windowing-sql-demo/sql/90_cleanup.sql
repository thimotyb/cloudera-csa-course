-- Stop eventual INSERT job dall'interfaccia SSB/Flink, poi esegui cleanup.

DROP TABLE IF EXISTS user_behavior_tumbling_out;
DROP TABLE IF EXISTS user_behavior_hopping_out;
DROP TABLE IF EXISTS user_behavior_cumulative_out;
DROP TABLE IF EXISTS user_behavior;
