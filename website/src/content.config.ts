import { defineCollection, z } from 'astro:content';

const tips = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    category: z.string(),
    focus: z.string().optional(),
    tags: z.array(z.string()).default([]),
    overview: z.string(),
    codeLabel: z.string().nullable().optional(),
    screenshot: z.string().nullable().optional(),
    week: z.number().optional(),
    weekLabel: z.string().optional(),
    order: z.number().optional(),
    slackText: z.string().optional(),
  }),
});

export const collections = { tips };
