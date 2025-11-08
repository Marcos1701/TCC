# Configuração do Java para Build Android

## Problema

O Android Gradle Plugin requer Java 17 para funcionar corretamente. Se você estiver usando Java 11, receberá o seguinte erro:

```
Android Gradle plugin requires Java 17 to run. You are currently using Java 11.
```

## Soluções

### Opção 1: Instalar Java 17 (Recomendado)

#### Windows

1. **Baixar Java 17:**
   - Acesse: https://adoptium.net/temurin/releases/
   - Escolha: Version 17 (LTS), Windows, x64
   - Baixe o instalador `.msi`

2. **Instalar:**
   - Execute o instalador
   - **IMPORTANTE**: Marque "Set JAVA_HOME variable" durante a instalação
   - Marque "Add to PATH"

3. **Verificar instalação:**
   ```powershell
   java -version
   # Deve mostrar: openjdk version "17.x.x"
   ```

#### macOS (Homebrew)

```bash
brew install openjdk@17

# Configurar JAVA_HOME no ~/.zshrc ou ~/.bash_profile
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc

# Verificar
java -version
```

#### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install openjdk-17-jdk

# Verificar
java -version

# Configurar JAVA_HOME no ~/.bashrc
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc
```

### Opção 2: Configurar `gradle.properties` para Java 17

Se você já tem Java 17 instalado mas não configurado como padrão:

1. Abra: `Front/android/gradle.properties`

2. Adicione (ajuste o caminho conforme sua instalação):

```properties
# Windows
org.gradle.java.home=C:\\Program Files\\Java\\jdk-17

# macOS
org.gradle.java.home=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home

# Linux
org.gradle.java.home=/usr/lib/jvm/java-17-openjdk-amd64
```

### Opção 3: Múltiplas versões do Java (Windows)

Se você precisa manter Java 11 para outros projetos:

1. **Instale Java 17** (não marque "Set JAVA_HOME")

2. **Configure apenas para este projeto:**
   - Edite `Front/android/gradle.properties`
   - Adicione: `org.gradle.java.home=C:\\Program Files\\Java\\jdk-17`

3. **Seu Java 11 permanecerá como padrão do sistema**

## Verificação

Após configurar, teste:

```bash
cd Front/android
./gradlew --version
# Deve mostrar JVM: 17.x.x
```

## Build do Projeto

Depois de configurar Java 17:

```bash
cd Front
flutter clean
flutter pub get
flutter build apk
```

## Problemas Comuns

### "JAVA_HOME não está definido"

**Windows PowerShell (temporário):**
```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
```

**Windows PowerShell (permanente):**
```powershell
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-17", "User")
```

**macOS/Linux (temporário):**
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

### Gradle ainda usa Java 11

1. Feche todos os terminais e IDEs
2. Abra novo terminal
3. Execute:
   ```bash
   echo $JAVA_HOME  # macOS/Linux
   echo %JAVA_HOME% # Windows CMD
   echo $env:JAVA_HOME # Windows PowerShell
   ```
4. Deve apontar para Java 17

### "Cannot find Java 17"

Verifique se o caminho está correto:

```bash
# Windows
dir "C:\Program Files\Java"

# macOS
ls /Library/Java/JavaVirtualMachines/

# Linux
ls /usr/lib/jvm/
```

## Nota Importante

⚠️ **Este projeto web/desktop funciona perfeitamente sem Java 17**. A configuração do Java só é necessária se você quiser compilar para Android.

Se você trabalha apenas com web/desktop, pode ignorar este erro de Java.
