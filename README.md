# WAPunch Web Frontend

A secure, enterprise-grade React application with comprehensive security features and modern UI components.

## 🚀 Features

- **React 18.3.1** + **TypeScript 5.5.3** + **Vite 5.4.0**
- **Security-First Design**: CSP headers, XSS protection, route guards, input validation
- **Modern UI**: Tailwind CSS with custom design tokens and dark/light themes
- **Authentication System**: Secure login/registration with validation
- **Route Protection**: Client-side route guards for role-based access
- **Responsive Design**: Mobile-first approach with Agent OS integration
- **Testing**: Playwright E2E tests with comprehensive coverage
- **Code Quality**: ESLint 9.x, Prettier, TypeScript strict mode

## 🛡️ Security Features

- Content Security Policy (CSP) configuration
- XSS and CSRF protection
- Input validation and sanitization
- Rate limiting utilities
- Secure authentication with localStorage
- Route-based access control
- Security headers (HSTS, X-Frame-Options, etc.)

## 🏗️ Architecture

```
src/
├── components/          # Reusable UI components
│   ├── Layout.tsx      # Main application layout
│   ├── RhemoLogo.tsx   # Custom SVG logo component
│   └── ui/             # UI component library
├── hooks/              # Custom React hooks
│   ├── useAuth.ts      # Authentication management
│   └── useSubmoduleNav.tsx # Navigation state management
├── lib/                # Utility libraries
│   ├── router.ts       # Client-side routing with guards
│   ├── security.ts     # Security utilities
│   └── colors.ts       # Color management
├── pages/              # Application pages
│   ├── personal/       # Personal view pages
│   ├── management/     # Management view pages
│   └── Inbox.tsx       # Shared pages
└── styles/             # Global styles and design tokens
```

## 🚦 Quick Start

### Prerequisites
- Node.js 18+ 
- npm or yarn

### Installation

```bash
# Clone the repository
git clone https://gitlab.com/adminrhemo-group/web-frontend.git
cd web-frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

### Available Scripts

```bash
npm run dev      # Start development server
npm run build    # Build for production
npm run preview  # Preview production build
npm run lint     # Run ESLint
npm run test     # Run Playwright tests
npm run format   # Format code with Prettier
```

## 🔧 Configuration

### Environment Setup

The application uses environment-specific configurations:

- **Development**: Hot reloading, relaxed CSP for development tools
- **Production**: Strict security headers, optimized bundles

### Security Configuration

Security settings are centralized in `src/lib/security.ts`:

- CSP policies
- Input validation rules
- Rate limiting settings
- CSRF token management

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
npm test

# Run tests in UI mode
npx playwright test --ui

# Run specific test file
npx playwright test tests/route-guards.spec.ts
```

## 🚀 Deployment

### Build for Production

```bash
npm run build
```

The `dist/` folder contains the optimized production build.

### Security Considerations for Production

- Update CSP headers for your domain
- Configure proper HTTPS certificates
- Set up server-side route validation
- Implement backend authentication
- Configure rate limiting at the server level

## 🏢 Agent OS Integration

This project is designed to work with Agent OS modules:

- `@ui-rules.md` - UI design guidelines
- `@tokens.md` - Design token specifications  
- `@components-guidelines.md` - Component standards
- `@checklists.md` - Quality assurance checklists

## 📱 Responsive Design

- **Mobile**: Single column, collapsed sidebar
- **Tablet**: Adaptive grid layout
- **Desktop**: Full multi-column layout with expanded sidebar

## 🎨 Design System

Uses a comprehensive design token system with:

- CSS custom properties for consistent theming
- HSL color values for better manipulation
- Semantic color naming (primary, secondary, accent)
- Typography scale and spacing system
- Component-specific design tokens

## 🔐 Security Architecture

### Client-Side Security
- Route guards prevent unauthorized access
- Input validation on all forms
- XSS protection via CSP
- CSRF token validation

### Recommended Server-Side Security
- Backend route validation
- JWT token authentication
- API rate limiting
- SQL injection prevention
- Server-side input validation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a merge request

### Development Guidelines

- Follow TypeScript strict mode
- Use ESLint and Prettier configurations
- Write tests for new features
- Update documentation as needed
- Follow the established component patterns

## 📄 License

This project is proprietary to RHemo Group.

## 🆘 Support

For support and questions:

- Create an issue in this repository
- Contact the development team
- Check the documentation in `/docs`

## 🗺️ Roadmap

- [ ] Server-side authentication integration
- [ ] Multi-factor authentication
- [ ] Advanced role-based permissions
- [ ] PWA features
- [ ] Internationalization (i18n)
- [ ] Advanced analytics integration

---

**Built with ❤️ by the RHemo development team**