import * as React from "react"

interface TooltipProps {
  children: React.ReactNode;
  content: string;
  side?: "top" | "bottom" | "left" | "right";
}

const TooltipProvider = ({ children }: { children: React.ReactNode }) => {
  return <>{children}</>;
};

const Tooltip = ({ children, content, side = "top" }: TooltipProps) => {
  const [isOpen, setIsOpen] = React.useState(false);

  return (
    <div
      className="relative inline-flex items-center"
      onMouseEnter={() => setIsOpen(true)}
      onMouseLeave={() => setIsOpen(false)}
      onFocus={() => setIsOpen(true)}
      onBlur={() => setIsOpen(false)}
    >
      {children}
      {isOpen && (
        <div
          className={`absolute z-50 px-3 py-1.5 text-xs text-white bg-gray-900 rounded-md shadow-lg whitespace-nowrap ${
            side === "top" ? "bottom-full left-1/2 -translate-x-1/2 mb-2" :
            side === "bottom" ? "top-full left-1/2 -translate-x-1/2 mt-2" :
            side === "left" ? "right-full top-1/2 -translate-y-1/2 mr-2" :
            "left-full top-1/2 -translate-y-1/2 ml-2"
          }`}
          role="tooltip"
        >
          {content}
          <div
            className={`absolute w-2 h-2 bg-gray-900 rotate-45 ${
              side === "top" ? "top-full left-1/2 -translate-x-1/2 -mt-1" :
              side === "bottom" ? "bottom-full left-1/2 -translate-x-1/2 -mb-1" :
              side === "left" ? "left-full top-1/2 -translate-y-1/2 -ml-1" :
              "right-full top-1/2 -translate-y-1/2 -mr-1"
            }`}
          />
        </div>
      )}
    </div>
  );
};

const TooltipTrigger = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement> & { asChild?: boolean }
>(({ asChild, children, ...props }, ref) => {
  if (asChild && React.isValidElement(children)) {
    return React.cloneElement(children, { ref, ...props });
  }
  return (
    <div ref={ref} {...props}>
      {children}
    </div>
  );
});
TooltipTrigger.displayName = "TooltipTrigger";

const TooltipContent = ({ children, ...props }: React.HTMLAttributes<HTMLDivElement>) => {
  return <div {...props}>{children}</div>;
};

export { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider };
