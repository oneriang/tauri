-- 创建示例表
CREATE TABLE IF NOT EXISTS example_table (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 插入示例数据
INSERT INTO example_table (name, description) VALUES 
('First Item', 'This is the first example item'),
('Second Item', 'Another example item with more details');
