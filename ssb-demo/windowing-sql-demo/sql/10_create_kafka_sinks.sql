DROP TABLE IF EXISTS user_behavior_tumbling_out;
DROP TABLE IF EXISTS user_behavior_hopping_out;
DROP TABLE IF EXISTS user_behavior_cumulative_out;

CREATE TABLE user_behavior_tumbling_out (
  window_start TIMESTAMP(3),
  window_end TIMESTAMP(3),
  buy_cnt BIGINT
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_behavior_tumbling_out',
  'properties.bootstrap.servers' = 'kafka:9092',
  'format' = 'json'
);

CREATE TABLE user_behavior_hopping_out (
  window_start TIMESTAMP(3),
  window_end TIMESTAMP(3),
  buy_cnt BIGINT
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_behavior_hopping_out',
  'properties.bootstrap.servers' = 'kafka:9092',
  'format' = 'json'
);

CREATE TABLE user_behavior_cumulative_out (
  window_start TIMESTAMP(3),
  window_end TIMESTAMP(3),
  buy_cnt BIGINT
) WITH (
  'connector' = 'kafka',
  'topic' = 'user_behavior_cumulative_out',
  'properties.bootstrap.servers' = 'kafka:9092',
  'format' = 'json'
);
