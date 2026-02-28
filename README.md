
## Quick start

```bash
mkdir -p ~/.claude && ( [ ! -d ~/.claude/skills ] || mv ~/.claude/skills ~/.claude/skills.bak.$(date +%Y%m%d%H%M%S) ) && git clone https://github.com/noobmastercn/claude-skills.git ~/.claude/skills
```
- anthropics/skills  https://github.com/anthropics/skills
- Apple-Hig-Designer: https://github.com/axiaoge2/apple-hig-designer 
- codex-code-review: https://github.com/tyrchen/claude-skills/tree/master/codex-code-review

- read-image: 只用于使用非claude 且有vision模型时使用例如：kimi k-2.5
```bash
curl -L https://github.com/OthmanAdi/planning-with-files/archive/master.tar.gz | tar -xzv --strip-components=2 "planning-with-files-master/skills/planning-with-files"
```

