using Documents.Api.Models;
using Documents.Api.Services;
using FluentValidation;
using MediatR;

namespace Documents.Api.Commands.DocumentCategoryCommands.Add
{
    public class AddDocumentCategoryCommand(CreateDocumentCategoryRequest createDocumentCategoryRequest) : IRequest<bool>
    {
        public CreateDocumentCategoryRequest Request { get; set; } = createDocumentCategoryRequest;

        public class AddDocumentCategoryCommandHandler(DocumentCategoryService service) : IRequestHandler<AddDocumentCategoryCommand, bool>
        {
            private readonly DocumentCategoryService _service = service;

            public Task<bool> Handle(AddDocumentCategoryCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return _service.Create(request.Request);
                }
                catch (Exception)
                {

                    throw;
                }
            }
            public class AddDocumentCategoryCommandValidator : AbstractValidator<AddDocumentCategoryCommand>
            {
                public AddDocumentCategoryCommandValidator()
                {
                    RuleFor(o => o.Request.Name).NotNull().NotEmpty().WithMessage("mut not be null.");
                    RuleFor(pid => pid.Request.LanguageKey).NotNull().NotEmpty().WithMessage("launguage key must not be null");
                }
            }
        }
    }
}
