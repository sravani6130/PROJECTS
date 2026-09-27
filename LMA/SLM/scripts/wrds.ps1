# File path
$file = "fineweb_eng.txt"

# Count words
(Get-Content $file | ForEach-Object { ($_ -split '\s+').Count }) | Measure-Object -Sum