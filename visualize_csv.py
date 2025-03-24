import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.table as tbl

# 讀取 CSV 文件
df = pd.read_csv('extracted_info.csv', sep='\t')

# 創建圖形和軸
fig, ax = plt.subplots(figsize=(12, 8))
ax.axis('tight')
ax.axis('off')

# 創建表格
table = tbl.table(ax, cellText=df.values, colLabels=df.columns, cellLoc='center', loc='center')

# 調整表格樣式
table.auto_set_font_size(False)
table.set_fontsize(10)
table.scale(1.2, 1.2)

# 顯示表格
plt.show()
