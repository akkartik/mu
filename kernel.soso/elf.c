#include "elf.h"
#include "common.h"
#include "process.h"
#include "screen.h"

BOOL isElf(char *elfData) {
    Elf32_Ehdr *hdr = (Elf32_Ehdr *) elfData;

    if (hdr->e_ident[0] == 0x7f && hdr->e_ident[1] == 'E' &&
        hdr->e_ident[2] == 'L' && hdr->e_ident[3] == 'F') {
        return TRUE;
    }

    return FALSE;
}

uint32 loadElf(char *elfData) {
    uint32 v_begin, v_end;
    Elf32_Ehdr *hdr;
    Elf32_Phdr *p_entry;
    Elf32_Scdr *s_entry;

    hdr = (Elf32_Ehdr *) elfData;
    p_entry = (Elf32_Phdr *) (elfData + hdr->e_phoff);

    s_entry = (Elf32_Scdr*) (elfData + hdr->e_shoff);

    if (isElf(elfData)==FALSE) {
        return 0;
    }

    for (int pe = 0; pe < hdr->e_phnum; pe++, p_entry++) {
        //Read each entry
        printkf("loading p_entry %d\n", pe);

        if (p_entry->p_type == PT_LOAD) {
            v_begin = p_entry->p_vaddr;
            v_end = p_entry->p_vaddr + p_entry->p_memsz;
            printkf("p_entry: %x\n", v_begin);
            if (v_begin < USER_OFFSET) {
                printkf("INFO: loadElf(): can't load executable below %x\n", USER_OFFSET);
                return 0;
            }

            if (v_end > USER_STACK) {
                printkf("INFO: loadElf(): can't load executable above %x\n", USER_STACK);
                return 0;
            }

            //printkf("ELF: entry flags: %x (%d)\n", p_entry->p_flags, p_entry->p_flags);


            printkf("about to memcpy\n");
            memcpy((uint8 *) v_begin, (uint8 *) (elfData + p_entry->p_offset), p_entry->p_filesz);
            printkf("done with memcpy\n");
            if (p_entry->p_memsz > p_entry->p_filesz) {
                char* p = (char *) p_entry->p_vaddr;
                for (int i = p_entry->p_filesz; i < (int)(p_entry->p_memsz); i++) {
                    p[i] = 0;
                }
            }
        }
    }

    //entry point
    printkf("done loading ELF\n");
    return hdr->e_entry;
}

