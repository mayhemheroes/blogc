// SPDX-License-Identifier: BSD-3-Clause
// In-process libFuzzer harness for blogc's source-file parser — the exact code path
// the `blogc <file>` CLI runs on each source file (front-matter config parsing +
// blogc_content_parse over the body). Replaces the raw-file CLI target `blogc`.

#include <stdint.h>
#include <stdlib.h>

#include "../src/blogc/source-parser.h"
#include "../src/common/error.h"
#include "../src/common/utils.h"

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    bc_error_t *err = NULL;
    // blogc_source_parse takes (src, src_len, toctree_maxdepth, err); it reads src[0..src_len).
    bc_trie_t *rv = blogc_source_parse((const char *) data, size, -1, &err);
    if (rv != NULL)
        bc_trie_free(rv);
    if (err != NULL)
        bc_error_free(err);
    return 0;
}
