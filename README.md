# pinyin

A lightning-fast, robust Crystal binding to **libpinyin**, designed for sentence-based intelligent Chinese Pinyin conversion.

It parses and segments Chinese phrases using `libpinyin`'s advanced linguistic databases, yielding highly accurate, context-aware Pinyin conversions.

## Features

- **Context-Aware Pinyin Segmentation:** Uses libpinyin's linguistic models to segment phrases and select the most accurate Pinyin pronunciation for polyphonic characters based on surrounding words.
- **Mixed-Text Robustness:** Seamlessly processes strings containing Chinese characters mixed with English, numbers, spaces, and punctuation.
- **Ultra High Performance:** Reuses context and instance pointers inside a single translation call, avoiding expensive DB reload disk I/O.
- **Character Fallback:** Fallbacks gracefully to character-by-character conversion if a complex phrase fails to segment.
- **Customizable:** Supports custom word/character separators and customized system/user database paths.

## Requirements

You must have `libpinyin` and `glib-2.0` libraries and their development headers installed on your system.

### Ubuntu / Debian

```bash
sudo apt-get install libpinyin15 libpinyin15-dev libpinyin-data pkg-config
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     pinyin:
       github: chi-vi/pinyin-cr
   ```

2. Run `shards install`

## Usage

```crystal
require "pinyin"

# 1. Standard Conversion
Pinyin.to_pinyin("北京大学")
# => "bei jing da xue"

# 2. Mixed Chinese & English Text (robust and format-preserving)
Pinyin.to_pinyin("你好，世界！ Hello World!")
# => "ni hao ， shi jie ！ Hello World!"

# 3. Custom Separators
Pinyin.to_pinyin("北京大学", separator: "-")
# => "bei-jing-da-xue"

# 4. Array-based Conversion (Perfect for HTML ruby/rt tags)
elements = Pinyin.to_pinyin_array("北京，你好！")
# => [
#      Pinyin::Element(@text="北", @pinyin="bei"),
#      Pinyin::Element(@text="京", @pinyin="jing"),
#      Pinyin::Element(@text="，", @pinyin="，"),
#      Pinyin::Element(@text="你", @pinyin="ni"),
#      Pinyin::Element(@text="好", @pinyin="hao"),
#      Pinyin::Element(@text="！", @pinyin="！")
#    ]

# Render HTML ruby/rt tags easily without nil-checks:
html_output = elements.map { |el|
  if el.text != el.pinyin
    "<ruby>#{el.text}<rt>#{el.pinyin}</rt></ruby>"
  else
    el.text
  end
}.join
# => "<ruby>北<rt>bei</rt></ruby><ruby>京<rt>jing</rt></ruby>，<ruby>你<rt>ni</rt></ruby><ruby>好<rt>hao</rt></ruby>！"
```

## System Paths & Custom Configs

By default, the library looks for system databases in `/usr/lib/x86_64-linux-gnu/libpinyin/data` and initializes a user-specific configuration directory at `~/.local/share/pinyin-cr`.

You can customize these globally via module properties:

```crystal
# Set globally at startup
Pinyin.user_dir = "/crux/confs"
Pinyin.system_dir = "/path/to/libpinyin/data"

# All subsequent calls automatically resolve to these paths:
Pinyin.to_pinyin("北京大学")
```

Alternatively, you can customize them on a per-call basis:

```crystal
Pinyin.to_pinyin(
  "北京大学",
  system_dir: "/path/to/libpinyin/data",
  user_dir: "/crux/confs"
)
```

> [!NOTE]
> `user_dir` must be a directory path. `libpinyin` expects a configuration file named `user.conf` to reside inside this directory. If it doesn't exist, the `pinyin` library will **automatically and silently initialize an empty `user.conf` for you** to avoid any warning printouts to stdout/stderr.

## Development & Testing

Run unit specs using Crystal's built-in testing framework:

```bash
crystal spec
```

## License

This library is released under the [MIT License](LICENSE).
