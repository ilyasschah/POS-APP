using MediatR;
using Api.Services;
using FluentValidation;

namespace Api.Commands.DocumentCategoryCommands.Delete
{
    public class DeleteDocumentCategoryCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }
        public DeleteDocumentCategoryCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }
        public class DeleteDocumentCategoryCommandHandler : IRequestHandler<DeleteDocumentCategoryCommand, bool>
        {
            private readonly DocumentCategoryService _service;
            public DeleteDocumentCategoryCommandHandler(DocumentCategoryService service)
            {
                _service = service;
            }
            public Task<bool> Handle(DeleteDocumentCategoryCommand request, CancellationToken cancellationToken)
            {
                return _service.Delete(request.Id, request.CompanyId);
            }
        }
        public class DeleteDocumentCategoryCommandValidator : AbstractValidator<DeleteDocumentCategoryCommand>
        {
            public DeleteDocumentCategoryCommandValidator()
            {
                RuleFor(sid => sid.Id).GreaterThan(0).WithMessage("Document Category ID must be valid.");
                RuleFor(cid => cid.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
