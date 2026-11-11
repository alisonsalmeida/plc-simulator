"""Generate obsidian-vault/ from the repository: docs and Dart modules, cross-linked."""

from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent.parent
VAULT = ROOT / "obsidian-vault"
AREAS = {
    "engine": ROOT / "packages/plc_core/lib",
    "app": ROOT / "lib",
}
IMPORT = re.compile(r"^import '([^']+)';", re.M)


def note_name(area: str, path: Path, base: Path) -> str:
    return f"{area}/" + str(path.relative_to(base).with_suffix("")).replace("/", ".")


def main() -> None:
    if VAULT.exists():
        shutil.rmtree(VAULT)
    (VAULT / ".obsidian").mkdir(parents=True)
    index = ["# PLC Simulator", "", "- [[docs/_index]]"]

    (VAULT / "docs").mkdir()
    docs = sorted((ROOT / "docs").glob("*.md")) + [ROOT / "README.md"]
    for d in docs:
        shutil.copy(d, VAULT / "docs" / d.name)
    (VAULT / "docs/_index.md").write_text(
        "# Docs\n\n" + "".join(f"- [[docs/{d.stem}]]\n" for d in docs)
    )

    for area, base in AREAS.items():
        files = sorted(base.rglob("*.dart"))
        names = {f.resolve(): note_name(area, f, base) for f in files}
        (VAULT / area).mkdir()
        for f in files:
            links = []
            for imp in IMPORT.findall(f.read_text()):
                if imp.startswith("package:plc_core/"):
                    links.append("[[engine/plc_core]]")
                elif not imp.startswith(("package:", "dart:")):
                    target = names.get((f.parent / imp).resolve())
                    if target:
                        links.append(f"[[{target}]]")
            body = f"# {f.relative_to(ROOT)}\n\nArea: [[{area}/_index]]\n\n## Imports\n\n"
            body += "".join(f"- {link}\n" for link in links) or "- none\n"
            (VAULT / f"{names[f.resolve()]}.md").write_text(body)
        (VAULT / f"{area}/_index.md").write_text(
            f"# {area}\n\n" + "".join(f"- [[{n}]]\n" for n in names.values())
        )
        index.append(f"- [[{area}/_index]]")

    (VAULT / "PLC Simulator.md").write_text("\n".join(index) + "\n")
    print(f"vault built: {len(docs)} docs, {sum(1 for _ in VAULT.rglob('*.md'))} notes")


if __name__ == "__main__":
    main()
