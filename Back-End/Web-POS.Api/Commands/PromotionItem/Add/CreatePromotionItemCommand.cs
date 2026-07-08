using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PromotionItem.Add
{
    public class CreatePromotionItemCommand : IRequest<PromotionItemDto>
    {
        public int CompanyId { get; set; }
        public CreateSinglePromotionItemRequest Request { get; set; }

        public CreatePromotionItemCommand(int companyId, CreateSinglePromotionItemRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class CreatePromotionItemCommandHandler : IRequestHandler<CreatePromotionItemCommand, PromotionItemDto>
        {
            private readonly PromotionItemService _service;
            public CreatePromotionItemCommandHandler(PromotionItemService service) => _service = service;

            public async Task<PromotionItemDto> Handle(CreatePromotionItemCommand command, CancellationToken cancellationToken)
            {
                return await _service.Create(command.CompanyId, command.Request);
            }
        }
    }
}