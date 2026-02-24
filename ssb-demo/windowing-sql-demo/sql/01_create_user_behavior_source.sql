DROP TABLE IF EXISTS user_behavior;

CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts TIMESTAMP(3),
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'faker',
    'rows-per-second' = '8',
    'fields.user_id.expression' = '#{number.numberBetween ''1'',''500''}',
    'fields.item_id.expression' = '#{number.numberBetween ''1'',''2000''}',
    'fields.category_id.expression' = '#{number.numberBetween ''1'',''50''}',
    'fields.behavior.expression' = '#{regexify ''(buy|pv|cart|fav){1}''}',
    'fields.ts.expression' = '#{date.past ''8'',''SECONDS''}'
);

-- Quick smoke test (facoltativo):
-- SELECT * FROM user_behavior;
