param(
    [Parameter(Mandatory = $true)]

    [string]$FileName,
    [switch]$v
)

# 若用户未提供 .java 后缀，则自动补上
if (-not $FileName.EndsWith(".java")) {
    $FileName = "$FileName.java"
}

# 记录当前目录
$originalPath = Get-Location

# 进入 src 目录（相对脚本所在目录）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$srcPath = Join-Path $scriptDir "src"

if (-not (Test-Path $srcPath)) {
    Write-Host "[ERROR] 未找到 src 目录 ($srcPath)" -ForegroundColor Red
    exit 1
}

Set-Location $srcPath
if ($v) { Write-Host "[INFO] 已进入 src 目录: $(Get-Location)" -ForegroundColor Green }

try {
    # 查找所有匹配的 Java 文件
    $files = Get-ChildItem -Path . -Recurse -Filter $FileName -ErrorAction SilentlyContinue

    if (-not $files) {
        Write-Host "[ERROR] 未找到名为 '$FileName' 的文件。" -ForegroundColor Yellow
        exit
    }

    foreach ($file in $files) {
        if ($v) { Write-Host "[INFO] 找到文件: $($file.FullName)" -ForegroundColor Green }

        # 编译 Java 文件
        if ($v) { Write-Host "[INFO] 正在编译..." -ForegroundColor Green }
        javac $file.FullName

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] 编译失败: $($file.FullName)" -ForegroundColor Red
            continue
        }

        # 计算类名（相对路径去掉扩展名，转换为包路径）
        $rootPath = (Get-Location).Path
        $relativeDir = $file.DirectoryName.Substring($rootPath.Length)
        $relativeDir = $relativeDir.TrimStart('\', '/')
        $packagePath = $relativeDir -replace '[\\/]', '.'

        $className = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

        if ($packagePath) {
            $fullClassName = "${packagePath}.${className}"
        } else {
            $fullClassName = $className
        }

        if ($v) { Write-Host "[INFO] 正在运行类: $fullClassName" -ForegroundColor Green }
        & java -cp $rootPath $fullClassName

        $classFiles = Get-ChildItem -Path $file.DirectoryName -Filter "$className*.class" -ErrorAction SilentlyContinue
        if ($classFiles) {
            if ($v) {
                Write-Host "[INFO] 删除 class 文件:" -ForegroundColor Green
                $classFiles | ForEach-Object { Write-Host " - $($_.FullName)" }
            }
            $classFiles | Remove-Item -Force
        }
    }
}
finally {
    # 无论成功或异常，都回到原目录
    Set-Location $originalPath
    if ($v) { Write-Host "[INFO] 已返回原目录: $(Get-Location)" -ForegroundColor Green }
}