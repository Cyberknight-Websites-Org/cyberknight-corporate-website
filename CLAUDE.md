# Cyberknight Websites - Corporate Website

This is the corporate website for Cyberknight Websites, built with Jekyll.

## Project Overview

**Business**: Cyberknight Websites provides web solutions for Knights of Columbus councils, including:
- Public-facing council websites
- Cyberknight Secure Portal for management (hosted at https://secure.cyberknight-websites.com)

**Owner**: Julian Lopez (JulianLopez@cyberknight-websites.com)
- Chancellor of K of C Council #2431 in Alhambra, CA
- Economics/Mathematics graduate from USC

## Site Structure

### Pages
- **Home** (`index.html`) - Apple-inspired landing page with hero, alternating product sections, and feature grid
- **About** (`about.md`) - Julian Lopez bio and company background
- **Pricing** (`pricing.md`) - Feature page with $10/month pricing
- **Contact** (`contact.md`) - Email and mailing address
- **Blog** (`blog/index.html`) - Jekyll posts (currently one placeholder post)
- **Documentation** (`docs/index.md`) - Simple guides section (currently stub content)

### Key Features Highlighted
**Council Websites:**
- Event pages
- Post pages
- Subscribe forms

**Cyberknight Secure Portal:**
- Meeting minutes storage and auto-generation
- K of C forms
- Email/SMS announcements
- Email newsletters
- Member directory

## Design System

### Colors
- **Accent Color**: `#3273DC` (RGB: 50, 115, 220) - Used for headings, links, buttons, scrollbars
- **Background**: `#fafafa` (off-white, not pure white)
- **Text Primary**: `#1d1d1f`
- **Text Secondary**: `#6e6e73`
- **Border**: `#d2d2d7`

### Typography
- System fonts (San Francisco style): `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`
- Clean, minimal, Apple-inspired design
- No excessive animations or JavaScript

### Design Principles
- **Simple and clean** - Apple-like aesthetic
- **Fast loading** - Minimal JavaScript, optimized assets
- **Clear communication** - Focus on content over flashy design
- **Responsive** - Works on all screen sizes

## Development

### Local Development
```bash
# Install dependencies
bundle install

# Start Jekyll server
./jekyll_serve_dev.sh

# Server runs at http://127.0.0.1:4000/
```

### Using the serve-jekyll Skill
The `/serve-jekyll` skill is configured for this project:
- Starts Jekyll on port 4000
- Accessible via Playwright at http://127.0.0.1:4000/
- No VPN/nginx setup needed (simplified from council website template)

### Jekyll Configuration
- Uses Jekyll 4.3+
- Plugins: jekyll-feed, jekyll-seo-tag
- Blog posts in `_posts/`
- Documentation in `_documentation/` collection
- Permalink structure: `/blog/:year/:month/:day/:title/`

### Production Deployment

The `server_build_script.sh` automates deployment to production servers:

**What it does:**
1. Clones the repository from GitHub
2. Builds the Jekyll site using Docker
3. Deploys to the specified nginx directory
4. Logs all activity with timing breakdowns

**Required parameters:**
- `JEKYLL_DIR` - Temporary directory for cloning and building
- `NGINX_DIR` - Target deployment directory for the built site
- `JEKYLL_BUILDER_IMAGE` - Docker image containing Jekyll and dependencies

**Example usage:**
```bash
./server_build_script.sh \
  JEKYLL_DIR=/path/to/build/directory \
  NGINX_DIR=/path/to/nginx/deployment \
  JEKYLL_BUILDER_IMAGE=cyberknight-council-template-builder
```

**Webhook configuration:**
The script is designed to work with webhook triggers. See the webhook JSON configuration in the repository for automated deployments on git push events.

**Logs:**
Build logs are saved to `/path/to/logs/cyberknight-corporate-website/build_TIMESTAMP.log` (or `./logs/` if the main log directory is not writable).

## Content Guidelines

### Product Descriptions
When referring to products, use these exact descriptions:

**Secure Portal:**
> "This secure web portal is the management hub for Knights of Columbus councils, letting leaders manage members, events, announcements, billing, newsletters, and meeting minutes in one place while integrating with email/SMS delivery and council website updates."

**Council Website:**
> "These are clean, public-facing council websites designed for Knights of Columbus councils. They're ideal for sharing council news, upcoming events, leadership information, membership details, and key documents in a simple, easy-to-maintain format. The sites are fast, reliable, and built to present council information clearly to members and the community."

### Tagline
> "The pen is mightier than the sword, but modern knights require both modern swords and modern pens."

### Value Proposition
Focus on the importance of digital communication (websites, email, SMS) in the modern age for Knights of Columbus councils.

## Placeholder Content

### Images
- Using https://placecats.com/ for placeholder images
- Format: `https://placecats.com/WIDTH/HEIGHT` (e.g., `https://placecats.com/1000/700`)
- These will be replaced with actual product screenshots later

### Blog
- Currently has one placeholder post about cutting onions (for demonstration)
- Future posts should focus on council management, web technology, or Knights of Columbus topics

### Documentation
- Currently has one stub guide "Getting Started with Your Council Website"
- Keep docs simple and static for now (no search, basic organization)
- Intended for customers to reference guides and tutorials

## Important Conventions

### No Over-Engineering
- Don't add features beyond what's requested
- Keep solutions simple and focused
- No unnecessary abstractions or complexity
- Comments only where logic isn't self-evident

### File Modifications
- Always prefer editing existing files over creating new ones
- Only create new files when absolutely necessary
- Read files before modifying them

### Git Workflow
- Commit meaningful changes with clear messages
- Include "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
- Don't use destructive git commands without explicit permission

### Design Consistency
- Maintain Apple-inspired aesthetic
- Use accent color (#3273DC) consistently
- Keep off-white background (#fafafa)
- No emojis unless explicitly requested
- System fonts only

## External Links

- **Secure Portal**: https://secure.cyberknight-websites.com (external service)
- **Contact Email**: JulianLopez@cyberknight-websites.com
- **Mailing Address**: 232 E 2nd St Unit A, PMB #8170, Los Angeles, CA 90012

## Future Enhancements

Potential future additions (not yet implemented):
- Searchable/categorized documentation
- More blog posts
- Actual product screenshots
- Favicon
- Contact form
- Testimonials section
- Case studies from actual councils

## Notes

- This site serves as the public-facing corporate website
- The actual council websites and secure portal are separate systems
- Primary goal: clearly communicate the value proposition and features to potential Knights of Columbus council customers
- Secondary goal: provide documentation and support for existing customers
