using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.DocumentCategoryCommands.Add
{
    public class AddDocumentCategoryCommand : IRequest<bool>
    {
        public CreateDocumentCategoryRequest Request { get; set; }
        public int CompanyId { get; set; }
        public AddDocumentCategoryCommand(CreateDocumentCategoryRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddDocumentCategoryCommandHandler(DocumentCategoryService service) : IRequestHandler<AddDocumentCategoryCommand, bool>
        {
            private readonly DocumentCategoryService _service = service;

            public Task<bool> Handle(AddDocumentCategoryCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return _service.Create(request.Request, request.CompanyId);
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
